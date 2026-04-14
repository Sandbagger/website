require "test_helper"

class PagesSmokeTest < ActionDispatch::IntegrationTest
  Sitepress.site.resources.each do |resource|
    next unless resource.mime_type.to_s.include?("html")

    test "renders #{resource.request_path}" do
      get resource.request_path
      assert_response :success,
        "#{resource.request_path} returned #{response.status}\n#{response.body.to_s[0, 500]}"
    end
  end
end
