# frozen_string_literal: true

class CollectionComponent < ApplicationComponent
  include PostCoverHelper

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
    metadata = [formatted_topic(resource.data["topic"]), formatted_date(resource.data["publish_at"])]
      .compact

    p(class: "article-meta") { metadata.join(" · ") } if metadata.any?
  end

  def formatted_topic(topic)
    return if topic.blank?

    topic.to_s.split(",").map(&:strip).join(" · ")
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
