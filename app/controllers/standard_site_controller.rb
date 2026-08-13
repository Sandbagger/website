# frozen_string_literal: true

class StandardSiteController < ApplicationController
  def publication
    uri = AtProtocol::StandardSite.registry.publication_uri
    return head :not_found unless uri

    render plain: uri, content_type: "text/plain"
  end
end
