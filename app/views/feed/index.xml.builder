xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "RSS Feed for William Neal's Website"
    xml.description "RSS Feed for William Neal's Website"
    xml.link feed_index_url
  end

    posts.each do | post |
        xml.item do
          xml.title post.data["title"]
       
          xml.pubDate post.data["publish_at"]
          xml.link 'https://williamneal.dev' + post.url
          xml.guid post.data["ur?"]
        end
    end
end
