require 'rufus-scheduler'
require 'sinatra'
require 'yaml'
require './helpers.rb'
require 'mongo'
require 'json'
require "sinatra/reloader" if development?

include Mongo
include Sinatra::UserHelper

# set up DB connection
if ENV['VCAP_SERVICES'].nil?
  db = Connection.new.db('qabase')
else
  host = JSON.parse(ENV['VCAP_SERVICES'])['mongodb 1.8'].first['credentials']['hostname'] rescue 'localhost'
  port = JSON.parse( NV['VCAP_SERVICES'])['mongodb-1.8'].first['credentials']['port'] rescue 27017
  database = JSON.parse( ENV['VCAP_SERVICES'] )['mongodb-1.8'].first['credentials']['db'] rescue 'qabase'
  username = JSON.parse( ENV['VCAP_SERVICES'] )['mongodb-1.8'].first['credentials']['username'] rescue ''
  password = JSON.parse( ENV['VCAP_SERVICES'] )['mongodb-1.8'].first['credentials']['password'] rescue ''
  db = Connection.new(host, port).db(database)
  db.authenticate(username, password)
  #items = db.collection('items')
end
items = db.collection('items')
counters = db.collection('counters')
parser = Sinatra::UserHelper::RssParser.new(items, counters)

scheduler = Rufus::Scheduler.start_new

scheduler.every("5m") do
  puts "Processing RSS"
  parser.process
end

puts "We are starting"
#puts Sinatra::UserHelper.methods.sort
#puts Sinatra::UserHelper.respond_to?("addToFile")

@@step = 10 # number of items per page

# remove trailing slash in all requests
before do
    request.path_info.sub! %r{/$}, ''
end

def page (items, first = 0, step = @@step)
  set = items.find({}, :fields => ['link', 'title', 'dc_date']).
        sort(:dc_date, :desc).
        skip(first * step).
        limit(step).to_a or []
  if !first.is_a?(Integer) || first < 0
    return [0, set]
  elsif set.size <= 0
    puts first
    puts set.size
    puts set.size / step
    first = items.count() / step
    return page(items, first)
  else
    return [first, set]
  end
end

get '/charts' do
  erb :charts
end

get '/charts/data' do
  data = {cols: [
    {id: "", label: "date", pattern: "",type: "string"},
    {id: "", label: "job postings", pattern: "",type: "number"}
    ],
    rows: []
  }
  counters.find.each do |e|
    data[:rows] << {c: [{v: e["date"] },{v: e["num"].to_i }]}
  end

  return JSON.dump(data)
end

get '/' do
  @current, @items = page(items)
  @current = 0
  erb :saved

  #file = open("test.txt", "r").read or "File empty"
end

get '/0' do
  redirect '/'
end

get '/:page' do
  first_item = params[:page].to_i
  @current, @items = page(items, first_item)
  erb :saved
end



error do
    "<p>Sorry, we got an error. Try again.</p>"
end

# get '/sys' do
#   @db = db.inspect.split(',')
#   erb :sys
# end

# get '/saved' do
#   @items = items.find().sort( [["dc_date", -1]])
#   erb :saved
# end

