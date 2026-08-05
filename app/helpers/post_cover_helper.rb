# frozen_string_literal: true

module PostCoverHelper
  def post_cover(resource) = Writing::Cover.find(resource)
end
