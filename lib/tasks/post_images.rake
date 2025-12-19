# frozen_string_literal: true

namespace :images do
  desc "Generate abstract SVG cover images for blog posts"
  task :generate_posts, [:overwrite] => :environment do |_t, args|
    files = Dir["app/content/pages/writing/*.{markerb,md,html.markerb}"]
    if files.empty?
      puts "No post files found."
      next
    end

    require Rails.root.join("lib/post_image_generator")
    overwrite = ActiveModel::Type::Boolean.new.cast(args[:overwrite])
    PostImageGenerator.new(files, overwrite: overwrite).generate_all
    puts "Generated images for #{files.size} posts in public/images/posts" + (overwrite ? " (overwritten)" : " (skipped existing)")
  end
end
