# frozen_string_literal: true

module PostCoverHelper
  def post_cover_path(resource)
    slug = Pathname(resource.request_path.to_s).basename.to_s
    file = Rails.root.join("public/images/posts", "#{slug}.svg")

    "/images/posts/#{slug}.svg" if file.file?
  end
end
