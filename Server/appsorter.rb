require 'sidekiq'
require 'pubnub'
require 'redis'
require 'itunes-search-api'
require 'miro'
require 'color_sort'
require 'paleta'
require 'work_queue'

Sidekiq.configure_server do |config|
  REDISTOGO_URL = "redis://localhost:6379/"
  uri = URI.parse(REDISTOGO_URL)
  @@redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  PUBNUB = Pubnub.new( subscribe_key: 'sub-c-4e928ca4-9616-11e5-b829-02ee2ddab7fe', publish_key: 'pub-c-2b55a965-bf95-425f-8e3f-3e4cac5689ea')
end

class AppSorter
  include Sidekiq::Worker

  def perform(sorting_id, count)
    puts "Performing a task for hash: #{sorting_id}"
    # 1. Fetch app bundles
    bundle_ids = JSON.parse(@@redis.get(sorting_id))

    # 2. Fetch images
    images_and_bundles = fetch_images(bundle_ids)

    # 3. Find dominant colors
    images_bundles_and_colors = find_dominant_colors(images_and_bundles)

    # 4. Sort colors
    sorted_colors = sort_colors(images_bundles_and_colors).uniq

    # 5. Group by color
    grouped_colors = group_colors(sorted_colors)

    result = match_apps_with_colors(images_bundles_and_colors, grouped_colors)
    response = @@redis.set(sorting_id.to_s, result.to_json)

    PUBNUB.publish(
      channel:sorting_id.to_s,
      message: response
    ) do |envelope| 
      puts envelope.parsed_response
    end
  end

  def match_apps_with_colors(apps_hash, colors)
    main_arry = []
    colors.map do |similar_colors|
      app_similar = []
      similar_colors.map do |color|
        apps_hash.map do |bundle_info|
          meta_data = bundle_info.first[1]
          if meta_data[:dominant_color] == color
            new_bundle_info = meta_data
            new_bundle_info[:bundle_id] = bundle_info.first[0]
            app_similar << new_bundle_info
          end
        end
      end
      main_arry << app_similar
    end

    main_arry
  end

  def fetch_images(bundle_ids = [])
    wq = WorkQueue.new(10)
    images_bundle_ids = []
    bundle_ids.map do |bundle_id|
      wq.enqueue_b do
        app = ITunesSearchAPI.lookup(:'bundleId' => bundle_id)
        unless app.nil?
          puts "#{bundle_id} icon found"
          images_bundle_ids << { bundle_id => { :image => app['artworkUrl512'] } }
        end
      end
    end
    wq.join

    images_bundle_ids
  end

  def find_dominant_colors(images_bundle_ids = [])
    wq = WorkQueue.new(10)
    images_bundle_ids.map do |images_and_bundle|
      images_and_bundle.map do |key, bundle_info|
        wq.enqueue_b do
          colors = Miro::DominantColors.new(bundle_info[:image]).to_hex
          dominant_color = colors.first[1..-1]
          bundle_info[:dominant_color] = dominant_color
        end
      end
      wq.join

      images_and_bundle
    end
  end

  def sort_colors(images_bundle_ids = [])
    unsorted_colors = []
    images_bundle_ids.map do |images_and_bundle|
      images_and_bundle.map do |key, bundle_info|
        # 1. Get all colors into an array 
        unsorted_colors << bundle_info[:dominant_color]
      end
    end
    # 2. Sort the array with colors
    ColorSort.sort(unsorted_colors)
  end

  def group_colors(colors = [], similar = 0.15)
    colors_grouped = []
    colors_group = []
    group = []
    colors.each_with_index do |hex_color, index|
      color = Paleta::Color.new(:hex, hex_color)
      next_hex = colors[index+1]
      unless next_hex.nil?
        second_color = Paleta::Color.new(:hex, next_hex)
        if color.similarity(second_color) > similar
          # Create new group
          unless group.empty?
            colors_grouped << group
          end
          group = [color.hex.downcase]
        else
          group << color.hex.downcase
        end
        if index + 2 == colors.length 
          if second_color.similarity(color) > similar
             # Create new group
          unless group.empty?
            colors_grouped << group
          end
          group = [second_color.hex.downcase]
        else
          group << second_color.hex.downcase
          end
        end
      end
    end
    colors_grouped << group
  end
end
