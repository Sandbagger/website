# frozen_string_literal: true

module Writing
  class Article < Literal::Object
    prop :path, Writing::Path, reader: :private
    prop :frontmatter, Writing::Frontmatter, reader: :private

    def self.from(resource)
      path = Writing::Path.new(resource.source.path)
      frontmatter = Writing::Frontmatter.from(resource.data, source_path: path.source_path)

      new(path:, frontmatter:)
    end

    def title = frontmatter.title

    def topics = frontmatter.topics

    def emoji = frontmatter.emoji

    def publication_date = path.publication_date

    def draft? = path.draft?

    def post? = path.post?

    def slug = path.slug

    def source_path = path.source_path

    def request_path = path.request_path

    def url = request_path

    private

    def after_initialize = freeze

    private :to_h, :to_hash
  end
end
