# frozen_string_literal: true

class ApplicationLayout < ApplicationView
  include Phlex::Rails::Layout
  include Phlex::Rails::Helpers::ContentFor
  include PageHelper

  ARTICLE_COVER_SIZES = "(max-width: 48rem) " \
    "min(calc(100vw - clamp(2.2rem, 8vw, 6rem)), 36rem), " \
    "22rem"

  def initialize
    @partials = []
    @cover_image = nil
    @page_title = nil
    @page_kind = :default
    @page_metadata = {}
  end

  def view_template
    doctype

    html(lang: "en") do
      head do
        title { "William Neal" }
        meta name: "viewport", content: "width=device-width,initial-scale=1"
        meta name: "referrer", content: "strict-origin-when-cross-origin"
        csp_meta_tag
        csrf_meta_tags
        stylesheet_link_tag "application", data_turbo_track: "reload"
        javascript_include_tag "application", data_turbo_track: "reload", defer: true
        link(
          rel: "apple-touch-icon",
          sizes: "180x180",
          href: "/apple-touch-icon.png"
        )
        link(
          rel: "icon",
          type: "image/png",
          sizes: "16x16",
          href: "/favicon-16x16.png"
        )
        link(rel: "manifest", href: "/site.webmanifest")
        link(rel: "mask-icon", href: "/safari-pinned-tab.svg", color: "#61b9d2")
        link(rel: "alternate", type: "application/rss+xml", title: "William Neal's RSS feed", href: "https://williamneal.dev/feed")
      end

      body do
        render NavComponent.new

        main(class: ["site-main", "page--#{@page_kind}"]) do
          article? ? article_page : standard_page
        end

        render FooterComponent.new
      end
    end
  end

  def cover_image(cover, alt: nil)
    @cover_image = {cover:, alt:}
  end

  # standard:disable Style/TrivialAccessors
  def markdown(md)
    @markdown = md
  end

  def page_title(title)
    @page_title = title
  end

  def page_kind(kind)
    @page_kind = kind.to_sym
  end

  def page_metadata(topics: [], publication_date: nil)
    @page_metadata = {topics:, publication_date:}.compact_blank
  end
  # standard:enable Style/TrivialAccessors

  def partial(component)
    @partials ||= []
    @partials << component
  end

  private

  def article?
    @page_kind == :article
  end

  def standard_page
    div(class: "page-content center flow") do
      h1 { @page_title } if @page_title
      raw @markdown if @markdown
      render_partials
    end
  end

  def article_page
    header(class: article_header_classes) do
      div do
        article_metadata
        h1(id: "article-title") { @page_title } if @page_title
      end

      if @cover_image
        cover = @cover_image.fetch(:cover)

        figure(class: "article-cover-frame") do
          img(
            src: cover.src,
            srcset: cover.srcset,
            sizes: ARTICLE_COVER_SIZES,
            width: cover.width,
            height: cover.height,
            alt: @cover_image[:alt],
            class: "article-cover"
          )
        end
      end
    end

    div(class: ["article-shell", "center", @page_metadata.any? ? nil : "article-shell--single"]) do
      article_facts if @page_metadata.any?

      article(class: "prose flow", aria: (@page_title ? {labelledby: "article-title"} : nil)) do
        raw @markdown if @markdown
      end
    end

    render_partials
  end

  def article_metadata
    topics = @page_metadata[:topics] || []
    date = formatted_publication_date
    return if topics.empty? && date.blank?

    p(class: "article-meta") do
      render TopicLinksComponent.new(topics)
      plain " · " if topics.any? && date.present?
      plain date if date
    end
  end

  def article_header_classes
    ["article-header", "center", @cover_image ? nil : "article-header--text-only"]
  end

  def article_facts
    aside(class: "article-facts") do
      span(class: "eyebrow") { "Filed under" }
      dl do
        topics = @page_metadata[:topics] || []
        fact("Topics") { render TopicLinksComponent.new(topics) } if topics.any?
        fact("Published", formatted_publication_date)
      end
    end
  end

  def fact(label, value = nil)
    return if value.blank? && !block_given?

    dt { label }
    dd { block_given? ? yield : value }
  end

  def formatted_publication_date
    @page_metadata[:publication_date]&.strftime("%-d %B %Y")
  end

  def render_partials
    @partials.each { |partial| render partial }
  end
end
