# Temporary shim for Rails 8 with litestack: the gem sets
# `config.active_record.sqlite3_production_warning`, but Rails 8 removed this
# accessor. Remove the config entry (so ActiveRecord doesn't try to copy it)
# and add a no-op accessor when Active Record loads.
if Rails.application.config.active_record.respond_to?(:delete)
  Rails.application.config.active_record.delete(:sqlite3_production_warning)
end

ActiveSupport.on_load(:active_record) do
  class << self
    attr_accessor :sqlite3_production_warning unless respond_to?(:sqlite3_production_warning)
  end
end
