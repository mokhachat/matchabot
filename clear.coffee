setting = require './setting'
_ = require 'lodash'
MilkCocoa = require "./lib/milkcocoa"

# DB
milkcocoa = new MilkCocoa setting.MILKCOCOA.URL

testDS = milkcocoa.dataStore "test"
tweetDS = milkcocoa.dataStore "tweet"
patternDS = milkcocoa.dataStore "pattern"

# all clear
testDS.query().done (data)->
  _.forEach data, (v)-> testDS.remove v.id

tweetDS.query().done (data)->
  _.forEach data, (v)-> tweetDS.remove v.id

patternDS.query().done (data)->
  _.forEach data, (v)-> patternDS.remove v.id


# uncaughtException
process.on 'uncaughtException', (err)->
  logger.error err.stack
