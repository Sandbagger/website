# frozen_string_literal: true

require "test_helper"

class StandardSiteIntegrationTest < ActionDispatch::IntegrationTest
  test "reserves the well-known publication verification endpoint" do
    get "/.well-known/site.standard.publication"

    assert_response :not_found
    assert_equal "", response.body
  end

  test "does not claim unpublished Standard.site records in page metadata" do
    get "/writing/pettis-good-tariffs-vs-bad"

    assert_response :success
    assert_select "head link[rel='site.standard.publication']", 0
    assert_select "head link[rel='site.standard.document']", 0
  end
end
