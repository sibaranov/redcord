# typed: strict
module Redcord::Migration::TTL
  extend T::Sig

  sig { params(model: T.class_of(Redcord::Base)).returns(T.untyped) }
  def _get_ttl(model)
    model.class_variable_get(:@@ttl) || -1
  end

  # This won't change ttl until we call update on a record
  sig { params(model: T.class_of(Redcord::Base)).void }
  def change_ttl_passive(model)
    model.redis.set("#{model.model_key}:ttl", _get_ttl(model))
  end

  sig { params(model: T.class_of(Redcord::Base)).void }
  def change_ttl_active(model)
    change_ttl_passive(model)
    model.redis.scan_each(match: "#{model.model_key}:id:*") do |key|
      model.redis.expire(key, _get_ttl(model))
    end
  end
end
