require 'mongo'
include Mongo
@client = MongoClient.new('0.0.0.0', 27017) 
$itemsdb = @client['itemsdb']
$items = $itemsdb['items']