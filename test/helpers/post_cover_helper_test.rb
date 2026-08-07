require "test_helper"

class PostCoverHelperTest < ActiveSupport::TestCase
  include PostCoverHelper

  Resource = Data.define(:request_path)

  test "returns cover metadata when a canonical cover exists" do
    resource = Resource.new("/writing/pettis-good-tariffs-vs-bad")

    cover = post_cover(resource)

    assert_instance_of Writing::Cover, cover
    assert_equal "/images/posts/pettis-good-tariffs-vs-bad-1200w.webp", cover.src
  end

  test "returns nil when a canonical cover is absent" do
    resource = Resource.new("/writing/does-not-have-a-cover")

    assert_nil post_cover(resource)
  end

  test "does not expose the legacy path-only helper" do
    legacy_method = %w[post cover path].join("_").to_sym

    refute_respond_to self, legacy_method
  end
end
