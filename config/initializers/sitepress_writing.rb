# frozen_string_literal: true

require Rails.root.join("lib/writing/path").to_s
require Rails.root.join("lib/writing/resource_pipeline").to_s

writing_resource_pipeline = Writing::ResourcePipeline.new(environment: Rails.env)

Sitepress.site.manipulate do |root|
  writing_resource_pipeline.process(root)
end

Rails.application.config.after_initialize do
  Sitepress.site.resources
  Sitepress.site.reload! unless Sitepress.configuration.cache_resources
end
