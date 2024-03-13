xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "RSS Feed for William Neal's Website"
    xml.description "RSS Feed for William Neal's Website"
    xml.link feed_index_url
    # Corrected atom:link element
    xml.tag!("atom:link", href: feed_index_url, rel: "self", type: "application/rss+xml")

    posts.each do |post|
      xml.item do
        xml.title post.data["title"]
        xml.pubDate post.data["publish_at"].strftime("%a, %d %b %Y %H:%M:%S %z")
        xml.link root_url + post.url
        xml.guid root_url + post.url, isPermaLink: "true"
      end
    end
  end
end