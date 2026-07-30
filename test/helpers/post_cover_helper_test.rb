require "test_helper"

class PostCoverHelperTest < ActiveSupport::TestCase
  include PostCoverHelper

  Resource = Data.define(:request_path)

  test "returns the public path when a generated cover exists" do
    resource = Resource.new("/writing/pettis-good-tariffs-vs-bad")

    assert_equal(
      "/images/posts/pettis-good-tariffs-vs-bad.svg",
      post_cover_path(resource)
    )
  end

  test "returns nil when a generated cover is absent" do
    resource = Resource.new("/writing/does-not-have-a-cover")

    assert_nil post_cover_path(resource)
  end
end
