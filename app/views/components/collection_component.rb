# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include PostCoverHelper

  FEATURE_COVER_SIZES = "(max-width: 48rem) " \
    "calc(100vw - clamp(2.2rem, 8vw, 6rem)), " \
    "min(60vw, 47rem)"

  def initialize(collection, context: :archive)
    @collection = collection || []
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

  def feature(resource)
    cover = post_cover(resource)

    article(class: ["writing-feature", cover ? nil : "writing-feature--text-only"]) do
      if cover
        a(
          href: resource.request_path,
          class: "writing-feature__cover",
          aria: {label: "Read #{resource_title(resource)}"}
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

      resource_metadata(resource)
      h3 { a(href: resource.request_path) { resource_title(resource) } }
    end
  end

  def rows(resources)
    return if resources.empty?

    ol(class: "article-list", role: "list") do
      resources.each do |resource|
        li(class: "article-row") do
          resource_metadata(resource)
          h3 { a(href: resource.request_path) { resource_title(resource) } }
          a(href: resource.request_path, aria: {label: "Read #{resource_title(resource)}"}) do
            "Read note →"
          end
        end
      end
    end
  end

  def resource_metadata(resource)
    topics = resource_topics(resource)
    date = formatted_date(resource.data["publish_at"])

    return if topics.empty? && date.blank?

    p(class: "article-meta") do
      render TopicLinksComponent.new(topics)
      plain " · " if topics.any? && date.present?
      plain date if date
    end
  end

  def resource_topics(resource)
    Writing::Topic.from(resource.data, source_path: resource_source_path(resource))
  end

  def resource_source_path(resource)
    source = resource.source if resource.respond_to?(:source)

    source&.path || resource.request_path
  end

  def formatted_date(date)
    date&.strftime("%-d %B %Y")
  end

  def resource_title(resource)
    resource.data["title"].presence || resource.request_path
  end

  def section_classes
    ["writing-collection", "writing-collection--#{modifier}", (@context == :article) ? "center" : nil]
  end

  def modifier
    (@context == :article) ? :more : @context
  end
end
