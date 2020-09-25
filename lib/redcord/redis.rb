# frozen_string_literal: true

# typed: false

require 'active_support/core_ext/module'

require_relative 'redis_shard'

# Delegate existing methods to all shards
class Redcord::Redis
  def initialize(*args)
    if args.first.is_a?(Hash) && args.first.keys.map(&:to_sym) == [:cluster]
      @clients = args
        .first
        .values
        .first
        .map { |arg| Redcord::RedisShard.new(arg) }
    else
      @clients = [Redcord::RedisShard.new(*args)]
    end
  end

  def shards
    @clients
  end

  def create_hash_returning_id(key, args)
    # Randomly place a new record on a shard
    shards.sample(1).first.create_hash_returning_id(key, args)
  end

  def update_hash(*args)
    each_shard { |shard| shard.update_hash(*args) }
  end

  def delete_hash(*args)
    each_shard { |shard| shard.delete_hash(*args) }
  end

  def find_by_attr(*args)
    records = {}
    each_shard { |shard| records.merge!(shard.find_by_attr(*args)) }
    records
  end

  def find_by_attr_count(*args)
    count = 0
    each_shard { |shard| count += shard.find_by_attr_count(*args) }
    count
  end

  def load_server_scripts!
    each_shard { |shard| shard.load_server_scripts! }
  end

  def hgetall(*args)
    res = nil
    each_shard { |shard| res ||= shard.hgetall(*args) }
    res
  end

  def hmget(*args)
    shards.hmget?(*args)
  end

  def self.server_script_shas
    Redcord::RedisShard.class_variable_get(:@@server_script_shas)
  end

  def self.load_server_scripts!
    Redcord::Base.configurations[Rails.env].each do |_, config|
      Redcord::RedisShard.new(**(config.symbolize_keys)).load_server_scripts!
    end
  end

  def each_shard(&blk)
    threads = shards.map do |shard|
      Thread.new do
        Thread.current.abort_on_exception = true
        Thread.current.report_on_exception = false

        blk.call(shard)
      end
    end

    threads.each { |t| t.join }
  end
end
