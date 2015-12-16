require 'open-uri'
require 'miro'
require 'sinatra'
require 'haml'
require 'color_sort'
require 'itunes-search-api'
require 'paleta'
require 'json'
require 'redis'

BUNLDE_URLS = ["com.tripadvisor.LocalPicks", "com.apple.itunesu", "com.readability.ReadabilityMobile", "com.8tracks.etracksapp", "com.skype.skype", "com.meetup.iphone", "com.google.ios.youtube", "com.hipchat.ios", "net.whatsapp.WhatsApp", "com.google.inbox", "com.facebook.Messenger", "com.magoosh.gre.quiz.vocabulary"]
configure do
  REDISTOGO_URL = "redis://localhost:6379/"
  uri = URI.parse(REDISTOGO_URL)
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

enable :sessions

def sort_apps
  puts session.id
  images_hash = REDIS.get(session.id)
  p images_hash = JSON.parse(images_hash)
  unsorted_colors = []
  colors_hash = {}
  app_color_hash = {}
  images_hash.map do |app_bundle_id,image_url|
    colors = Miro::DominantColors.new(image_url).to_hex
    color = colors.first[1..-1]

    app_color_hash[color] = {color => image_url}

    if colors_hash[color].nil?
      colors_hash[color] = [image_url]
    else
      colors_hash[color] << image_url
    end

    unsorted_colors << color
  end

  group_count = 0
  grouped_colors = {}
  main_colors = ColorSort.sort(unsorted_colors)
  puts "main colors #{main_colors}"
  main_colors.each_with_index do |hex_color, i|
    color = Paleta::Color.new(:hex, hex_color)
    next_hex = main_colors[i+1]
    unless next_hex.nil?
      color1 = Paleta::Color.new(:hex, next_hex)
      similarity = color.similarity(color1) # Something is wrong here 
      puts "similarity between: #{color} x #{color1} is #{similarity}"
      if similarity > 0.15
        puts "creating a group"
        group_count = group_count + 1
        if grouped_colors["color_group_#{group_count}"].nil?
          grouped_colors["color_group_#{group_count}"] = [color1.hex.downcase]
        else
          grouped_colors["color_group_#{group_count}"] << color1.hex.downcase
        end
      else
        puts "adding to a groupt"
        if grouped_colors["color_group_#{group_count}"].nil?
          grouped_colors["color_group_#{group_count}"] = [color.hex.downcase, color1.hex.downcase]
        else
          grouped_colors["color_group_#{group_count}"] << color.hex.downcase
          grouped_colors["color_group_#{group_count}"] << color1.hex.downcase
        end
      end
      grouped_colors["color_group_#{group_count}"].uniq!
    end
  end

  response = []
  group_hash = {}
  puts "grouped colors"
  puts grouped_colors
  grouped_colors.map do |group, color_array|
    group_hash[group] = []
    color_hash = []
    color_array.map do |color|
      # if color_hash[color].nil?
        color_hash << app_color_hash[color][color]
      # else
        # color_hash[color] << [color]
      # end
    end

    group_hash[group] << color_hash
    response << group_hash[group]
  end
  puts response

  return response.to_json
  # Response: 
  # [
  #   group_1: [
  #     {
  #       ffssfa: [         [
  #           "file-x.jpg"
  #       ]
  #     }
  #   ]
  # ]

    # %tbody
    # - grouped_colors.map do |k,color_array|
    #   - color_array.each do |color|
    #     %tr
    #       %td{style: "background-color:##{color}"}= color
    #       %td
    #         - colors_hash[color].each do |file|
    #           %img{:src => file, :style => "height:42px; width:42px" }
    #   %tr
    #     %td ---

  haml :sort, :locals => {
    :main_colors => main_colors,
    :colors_hash => colors_hash,
    :grouped_colors => grouped_colors
  }
end

def setup
  count = 0
  images_hash = {}
  bundle_ids = JSON.parse(REDIS.get(session.id))
  bundle_ids.map do |bundle_id|
    app = ITunesSearchAPI.lookup(:'bundleId' => bundle_id)
    unless app.nil?
      images_hash[bundle_id] = app['artworkUrl512']
      puts images_hash[bundle_id]
    end
  end

  REDIS.set(session.id,images_hash.to_json)
  # @images_urls.map do |url|
  #   image_path = "./public/file-#{count = count + 1}.png"
  #   unless File.file?(image_path)
  #     open(url) do |f|
  #       File.open(image_path,'wb') do |file|
  #         file.puts f.read
          # @images_paths << image_path
  #       end
  #     end
  #   end
  # end
  
  sort_apps
end

post '/' do
  REDIS.flushall
  json = JSON.parse(request.body.read)
  puts "Received json #{json}"
  REDIS.set(session.id,json)

  puts session.id
  setup
end

__END__

@@ layout
%html
  = yield

@@ sort
%table
  %tbody
    - grouped_colors.map do |k,color_array|
      - color_array.each do |color|
        %tr
          %td{style: "background-color:##{color}"}= color
          %td
            - colors_hash[color].each do |file|
              %img{:src => file, :style => "height:42px; width:42px" }
      %tr
        %td ---
