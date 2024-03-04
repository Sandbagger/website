xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "RSS Feed for William Neal's Website"
    xl.description "RSS Feed for William Neal's Website"
    xml.link feed_index_url

    posts.each do post|
      xml.item do
        xml.title post.data["title"]
        xml.description ERB::Util.html_escape_once(renderer.render(post.body).html_safe)
        xml.pubDate post.data[ "published" ]
        xml.link post.data["url"]
        xml.guid post.data["ur?"]
      end
    end
  end
end