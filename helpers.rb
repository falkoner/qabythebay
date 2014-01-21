require 'simple-rss'
#require 'thoughtafter-simple-rss'
require 'open-uri'

module Sinatra
  module UserHelper
    def UserHelper.addToFile
      puts "Adding"
      open("test.txt", 'a') do |i|
        i.puts Time.now.to_s + "\n"
      end
    end

    def UserHelper.get_db_connection
      if ENV['MONGOHQ_URL'].nil?
        db = Connection.new.db('qabase')
      else
        db_heroku = URI.parse(ENV['MONGOHQ_URL'])
        database = db_heroku.path.gsub(/^\//, '')
        db = Mongo::Connection.new(db_heroku.host, db_heroku.port).db(database)
        db.authenticate(db_heroku.user, db_heroku.password) unless (db_heroku.user.nil? || db_heroku.password.nil?)
      end

      return db
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
        begin
          rss = SimpleRSS.parse open(@url)
          rss.channel.items.each do |item|
            if check(item.title)
              save(item) if @db
              @new_items.push :title => item.title, :link => item.link
            end
          end
        rescue Exception => e
          puts e.message
        end
      end

      def get
        puts "Returning new items - " + @new_items.size.to_s
        return @new_items
      end

      def save(item)
        item.delete(:dc_rights)
        item.delete(:dc_title)
        item[:location] = getLocation(item)
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

      def getLocation(item)
        location = nil
        if item[:title].scan(/\([^)]*\)$/)
          location = item[:title].scan(/\([^)]*\)$/)[0]
          location.gsub!(/[()]/,'')
        end
        return location
      end

      def clean(item)
        item.each do |k, v|
          if v.is_a?(String)
            item[k].encode!("UTF-8", {:invalid => :replace, :undef => :replace, :replace => '?'})
            #item[k] = v.scan(/[a-z\d :\/\,\.\+\#\&\-\)\(@]/i).join.strip if v.is_a?(String)
          end
        end

      end


    end

  end

  helpers UserHelper
end
