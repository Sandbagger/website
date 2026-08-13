# frozen_string_literal: true

require "io/console"

namespace :standard_site do
  desc "Publish the site's Standard.site records to its AT Protocol PDS"
  task publish: :environment do
    password = ENV["ATPROTO_APP_PASSWORD"]
    password = IO.console&.getpass("AT Protocol app password: ") if password.blank?
    if password.blank?
      abort "ATPROTO_APP_PASSWORD is required; use an app password, not the account password"
    end
    registry = AtProtocol::StandardSite.registry
    identifier = ENV.fetch("ATPROTO_IDENTIFIER", registry.did)
    client = AtProtocol::Client.authenticate(
      pds_url: registry.pds_url,
      identifier:,
      password:
    )
    catalogue = Writing::Catalogue.new(
      resources: Sitepress.site.resources,
      policy: Writing::PublicationPolicy.new(environment: "production")
    )

    AtProtocol::StandardSite::Publisher.new(
      client:,
      registry:,
      articles: catalogue.published
    ).publish
  end
end
