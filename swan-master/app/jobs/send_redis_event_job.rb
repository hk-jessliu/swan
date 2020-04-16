class SendRedisEventJob < ApplicationJob
  queue_as :default

  def perform(event, data)
    redis = Redis.new(host: Rails.configuration.swan['redis']['host'], port: Rails.configuration.swan['redis']['port'])
    msg = Hash.new
    msg['event'] = event
    if data
        msg['data'] = data
    else
        msg['data'] = {}
    end
    redis.lpush(Rails.configuration.swan['redis']['channel'], msg.to_json)
  end
end
