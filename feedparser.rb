require 'rss'

require './alchemyapi.rb'

require 'net/http'
require 'open-uri'

require 'mongo'
include Mongo
@client = MongoClient.new('0.0.0.0', 27017) 
$itemsdb = @client['itemsdb']
$items = $itemsdb['items']
$feeds = $itemsdb['feeds']


module Feedparser
    
    #adding feeds that every user starts with, should be ran one time at the initial set up of the system
    def self.addStarterFeeds
        starterFeeds = [{url: 'http://feeds.bbci.co.uk/news/rss.xml', name:'BBC', description:'general news'}]
        
        #incremental id
        last_entry = $feeds.find().sort( :_id => :desc ).to_a
        if(last_entry.nil? or last_entry.empty?)
            id = 1
        else
            id = last_entry[0]['_id'] + 1
        end
        
        #insert in db
        for feed in starterFeeds
            existing_entry = $feeds.find( {url: feed['url'] }).to_a
            if(existing_entry.empty?)
                feed['_id'] = id
                $feeds.insert(feed)
                id = id + 1
            else
                puts('Warning: you tried to insert a feed url into feeds collection that already contained that url')
                return
            end
        end
    end


    #todoLater: for adding individual urls
    def self.addFeed url
    
    end
    
    
    def self.parseFeeds
        feeds = $feeds.find().to_a
        for feed in feeds
            self.parseFeed feed
        end
    end
    
    
    def self.parseFeed feed, printResult = true#TODO change this to false

        response = RSS::Parser.parse(feed['url'],false)

        items = Array.new

        if response.feed_type == "rss"
            response.channel.items.each{ |item| items << { url: item.link, title: item.title, description: item.description, feed_id: feed['_id'] } }
        elsif response.feed_type == "atom"
            response.entries.each{ |entry| items << {url: entry.link.href} } #TODO get title and desc for atom too, also atom's never been tested 
        else
            puts "something went wrong"
        end
        
        puts
        #incremental id
        last_entry = $items.find().sort( :_id => :desc ).to_a
        if(last_entry.nil? or last_entry.empty?)
            id = 1
        else
            id = last_entry[0]['_id'] + 1
        end
        
        puts("items.count = #{items.count}")
        puts("first item  = #{items[0]}")
        puts("first title  = #{items[0][:title]}")


    #   puts("we hea")
    #   for item in items
    #       puts("text tags")
    #       puts(self.tagText(item[:title]+" "+item[:description]))
    #       puts("url tags z")
    #       puts(self.tagUrl item[:url])
    #       puts("url strict tags")
    #       puts(self.tagUrl item[:url], {"keywordExtractMode" => 'strict'})
    #   end
        
        
        for item in items
            puts("alchemy response:")
            puts(self.tagText(item[:title]+" "+item[:description]))
            
            alchemyWordScores = Array.new(self.tagText(item[:title]+" "+item[:description])["keywords"])
            alchemyWords = Array.new
            for wordScore in alchemyWordScores
                alchemyWords << wordScore["text"]
            end
            puts("alchemyWords = ")
            puts(alchemyWords)
            item['alchemyWords'] = alchemyWords
            
            
            titleWords = Array.new
            for word in item[:title].split()
                if word.length > 3
                    titleWords << word
                end
            end
            item['titleWords'] = titleWords

            puts("title = #{item['alchemyWords']}")
            puts("title = #{item['titleWords']}")
            if(not $items.find({title: item[:title], feed_id: item[:feed_id].to_i}).to_a.empty?)
                puts("Note: Attemtping to insert duplicate item for feed #{feed['url']}, item url = #{item['url']}, stoping update for this feed")
                return
            else
                item['_id'] = id
                $items.insert(item)
                id = id+1
            end

        end
    end
    

    def self.tagUrl url, options = {}
        alchemy = AlchemyAPI.new()
        puts(alchemy.keywords('url', url, options))
        
     #  strictKeywords = "http://access.alchemyapi.com/calls/url/URLGetRankedKeywords?apikey=eac905f6e67704c251bfe593b01daa9d308cdb0f&url=#{URI.parse(url)}&keywordExtractMode=strict&outputmode=json"
     #  normalKeywords = "http://access.alchemyapi.com/calls/url/URLGetRankedKeywords?apikey=eac905f6e67704c251bfe593b01daa9d308cdb0f&url=#{URI.parse(url)}&outputmode=json"
     #  
     #  jsonStrict= Net::HTTP::get_response(URI.parse(strictKeywords))
     #  jsonNormal = Net::HTTP::get_response(URI.parse(normalKeywords))
    end

    def self.tagText text
        alchemy = AlchemyAPI.new()
        alchemy.keywords('text', text)
        
#        normalKeywordsUri = "http://access.alchemyapi.com/calls/text/TextGetRankedKeywords?apikey=eac905f6e67704c251bfe593b01daa9d308cdb0f&outputmode=json&text=#{URI.escape(text)}&showSourceText=1"
#        open(normalKeywordsUri, "UserAgent" => "Ruby-OpenURI").read
#        puts(URI.parse(normalKeywordsUri))
#        jsonNormal = Net::HTTP::get_response(URI.parse(normalKeywordsUri))
    end

end
