# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include PostCoverHelper

  FEATURE_COVER_SIZES = "(max-width: 48rem) " \
    "calc(100vw - clamp(2.2rem, 8vw, 6rem)), " \
    "min(60vw, 47rem)"

  def initialize(collection, context: :archive)
    @collection = collection || []
    unless @collection.all? { |article| article.is_a?(Writing::Article) }
      fail ArgumentError, "collection must contain Writing::Article instances"
    end

    @context = context.to_sym
  end

  def view_template
    return if @context == :article && @collection.empty?

    section(class: section_classes) do
      case @context
      when :home then home_collection
      when :article then more_collection
      else archive_collection
      end
    end
  end

  private

  def home_collection
    collection_header("Selected writing")

    if @collection.empty?
      p(class: "empty-state") { "New writing will appear here." }
    else
      feature(@collection.first)
      rows(@collection.drop(1).first(3))
    end
  end

  def archive_collection
    h2 { "All writing" }

    if @collection.empty?
      p(class: "empty-state") { "No published writing yet." }
    else
      rows(@collection)
    end
  end

  def more_collection
    collection_header("More writing")
    rows(@collection)
  end

  def collection_header(title)
    header(class: "collection-header cluster-around") do
      h2 { title }
      a(href: "/writing") { "Everything in the archive →" }
    end
  end

  def feature(article)
    cover = post_cover(article)

    article(class: ["writing-feature", cover ? nil : "writing-feature--text-only"]) do
      if cover
        a(
          href: article.request_path,
          class: "writing-feature__cover",
          aria: {label: "Read #{article.title}"}
        ) do
          img(
            src: cover.src,
            srcset: cover.srcset,
            sizes: FEATURE_COVER_SIZES,
            width: cover.width,
            height: cover.height,
            alt: ""
          )
        end
      end

      article_metadata(article)
      h3 { a(href: article.request_path) { article.title } }
    end
  end

  def rows(articles)
    return if articles.empty?

    ol(class: "article-list", role: "list") do
      articles.each do |article|
        li(class: "article-row") do
          article_metadata(article)
          h3 { a(href: article.request_path) { article.title } }
          a(href: article.request_path, aria: {label: "Read #{article.title}"}) do
            "Read note →"
          end
        end
      end
    end
  end

  def article_metadata(article)
    topics = article.topics
    date = formatted_date(article.publication_date)

    return if topics.empty? && date.blank?

    p(class: "article-meta") do
      render TopicLinksComponent.new(topics)
      plain " · " if topics.any? && date.present?
      plain date if date
    end
  end

  def formatted_date(date)
    date&.strftime("%-d %B %Y")
  end

  def section_classes
    ["writing-collection", "writing-collection--#{modifier}", (@context == :article) ? "center" : nil]
  end

  def modifier
    (@context == :article) ? :more : @context
  end
end
