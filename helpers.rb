require 'simple-rss'
#require 'thoughtafter-simple-rss'
require 'open-uri'

module Sinatra
  module UserHelper
    def addToFile
      puts "Adding"
      open("test.txt", 'a') do |i|
        i.puts Time.now.to_s + "\n"
      end
    end

    class RssParser

      def initialize(db = nil, counters = nil)
        @db = db
        @counters = counters
        @url = 'http://sfbay.craigslist.org/sof/index.rss'
        @new_items = Array.new
        process
      end

      def process
        rss = SimpleRSS.parse open(@url)
        rss.channel.items.each do |item|
          if check(item.title)
            save(item) if @db
            @new_items.push :title => item.title, :link => item.link
          end
        end
      end

      def get
        puts "Returning new items - " + @new_items.size.to_s
        return @new_items
      end

      def save(item)
        item.delete(:dc_rights)
        item.delete(:dc_title)
        item[:date] = (item[:dc_date] + Time.zone_offset("PST")).strftime("%F")
        item = clean(item)
        unless @db.find(:link => item[:link]).first
          @db.insert(item)
          # puts item[:dc_date].localtime.strftime("%F")
          @counters.update({:date => (item[:dc_date] + Time.zone_offset("PST")).strftime("%F")},
                           {:$inc => {:num => 1}},
                           {:upsert => true })
          puts "saving new item #{item[:link]}"
          #else
          #  puts "Already in place: #{@db.find(:link => item[:link]).first["link"]}"
        end

      end


      def check(string)
        keywords = /QA|Test|Quality|QE\W/i
        string =~ keywords
      end

      def clean(item)
        item.each do |k, v|
          if v.is_a?(String)
            item[k].encode!("UTF-8") if v.is_a?(String)
            #item[k] = v.scan(/[a-z\d :\/\,\.\+\#\&\-\)\(@]/i).join.strip if v.is_a?(String)
          end
        end

      end


    end

  end

  helpers UserHelper
end
