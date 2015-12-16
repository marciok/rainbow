require 'sinatra/base'
require './appsorter'
require 'pubnub'

class Rainbow < Sinatra::Base
  configure do
    REDISTOGO_URL = "redis://localhost:6379/"
    uri = URI.parse(REDISTOGO_URL)
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    PUBNUB = Pubnub.new(
      subscribe_key: 'sub-c-4e928ca4-9616-11e5-b829-02ee2ddab7fe', 
      publish_key: 'pub-c-2b55a965-bf95-425f-8e3f-3e4cac5689ea'
    )
  end

  post '/apps' do
    # 1. create a hash with the session id on redis
    json = JSON.parse(request.body.read)
    sorting_id = save_apps(json)

    # 2. create a channel with the session id as name
    create_channel(sorting_id.to_s)

    # 3. get all the apps and put them into a line for the worker
    start_worker(sorting_id).to_json

    # 4. return the session id
    sorting_id.to_s
  end

  get '/apps/:sorting_id' do
    # 1. fetch the task by the session id
    sorting_id = params[:sorting_id]

    # 2. if ready retur otherwise return empty
    REDIS.get(sorting_id)
  end

  def save_apps(json)
    sorting_id = ('a'..'z').to_a.shuffle[0,8].join
    REDIS.set(sorting_id,json)
    sorting_id
  end

  def start_worker(sorting_id)
    result = AppSorter.perform_async(sorting_id, 1)
  end

  def create_channel(channel_name)
    PUBNUB.subscribe(channel: channel_name) do |envelope| 
      # puts envelope.message
    end
  end

end


