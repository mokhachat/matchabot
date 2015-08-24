setting = require './setting'
util = require './lib/util'
TwitterClient = require './lib/twitter_client'

express = require 'express'
http = require 'http'
{EventEmitter} = require 'events'
{exec, spawn} = require 'child_process'

_ = require 'lodash'
log4js = require 'log4js'
Fiber = require 'fibers'
kuromoji = require 'kuromoji'
require 'colors'

ins = require('util').inspect


# kuromoji
KUROMOJI_DIC_DIR = "./node_modules/kuromoji/dist/dict/"

# logger
log4js.configure
  appenders: [
    "type": "console"
  ,
    "type": "file"
    "category": "app"
    "maxLogSize": 20480
    "filename": "./app.log"
  ]

logger = log4js.getLogger "app"
logger.setLevel "DEBUG"


# server
app = express()
app.get '/', (req, res)-> res.send 'matcha oishii matcha'

server = app.listen setting.PORT, ->
  logger.info "Express server listening at #{server.address().port} port"


# twitter
tw_client = new TwitterClient app, '1.0A', setting.TWITTER.CONSUMER_KEY, setting.TWITTER.CONSUMER_SECRET, setting.TWITTER.ACCESS_TOKEN, setting.TWITTER.ACCESS_SECRET

class TwitterBot
  constructor: (@client, @tokenize)->
    @action = new EventEmitter()
    @self_id = setting.TWITTER.OWNER_ID
    @commands = []
    @response = []
    @resonance = []

  start: ->

    tw_callback = (err, res)->
      return unless err
      logger.error "#{ins err}".red if err
      logger.debug "result: #{ins res}".green if res

    tps = 0

    setInterval (-> tps = 0), 1000

    @action.on "error", (data)=>
      logger.error "error: #{ins data}".red
      @client.tweet "#{ins data}", tw_callback

    @action.on "tweet", (data)=>
      tps++
      if tps > 3
        @client.tweet "@#{setting.PARENT} 異常を確認しました。終了します。"
        setTimeout (-> process.exit 1), 1000
        return
      data.text = @afterReplace data.text
      logger.debug "tweet: #{ins data}".cyan
      @client.tweet data.text, tw_callback

    @action.on "reply", (data)=>
      data.text = @afterReplace data.text
      logger.debug "reply: #{ins data}".cyan
      @client.reply data.screen_name, data.text, data.status_id, tw_callback

    @action.on "favorite", (data)=>
      logger.debug "favorite: #{ins data}".cyan
      @client.favorite data.status_id, tw_callback

    @action.on "unfavorite", (data)=>
      logger.debug "unfavorite: #{ins data}".cyan
      @client.unfavorite data.status_id, tw_callback

    @connect = =>
      @client.userstream {include_followings_activity: true}, (stream)=>
        stream.once 'data', (data)->
          logger.info "streaming start.".green

        stream.on 'data', (data)=>
          data = @client.parseData data
          if data.type?
            switch data.type
              when 'tweet' then @procTweet data
              when 'favorite' then @procActivity data
              when 'direct_message' then @procDM data
              when 'follow' then @procFollow data
              when 'delete' then @procDelete data
              when 'user_update' then @procUserUpdate data

        stream.on 'error', (error)->
          logger.error "error: #{ins error}".red

        stream.on 'end', =>
          logger.info "stream end.".red
          setTimeout (=> @reconnect()), 1000

    @addCommand /stop/i, (screen_name, text, cb)->
      setTimeout (-> process.exit 1), 1000
      cb "終了します"

    @addCommand /ping/i, (screen_name, text, cb)->
      cb "pong"
      
    @addCommand /date/i, (screen_name, text, cb)->
      exec 'date', (error, stdout, stderr)->
        cb "\n#{stdout}"

    @addCommand /lasterror/i, (screen_name, text, cb)->
      exec 'cat app.log.1 app.log | grep ERROR | tail -1', (error, stdout, stderr)->
        cb "\n#{stdout}"

    @addCommand /lastwarn/i, (screen_name, text, cb)->
      exec 'cat app.log.1 app.log | grep WARN | tail -1', (error, stdout, stderr)->
        cb "\n#{stdout}"

    @addResponse /./, (screen_name, text, token, cb)-> 
      console.log "#{ins token}"
      false

    @addResponse /./, (screen_name, text, token, cb)-> 
      parts = _.map token, 'conj'
      if parts.some((v)-> /命令/.test v)
        cb util.randArray ["嫌ー！", "嫌ー！！", "嫌ー！嫌ー！！"]
        return true
      false

    @addResponse /./, (screen_name, text, token, cb)=>
      @createResponse text, token, (text)->
        cb text
      true
    
    @addResonance /matcha|まっちゃ/i, (text, cb)->
      cb util.randArray ["まっちゃ", "matcha", "MATCHA", "Matcha", "マッチャ", "抹茶"]
      true

    @addResonance /抹茶bot/, (text, cb)->
      cb util.randArray ["抹茶おいしい！抹茶！", "∵ゞ(＞д＜)ﾊｯｸｼｭﾝ!", "(　>д<)､;'.･　ｨｸｼｯ", "(* >ω<)=3ﾍｯｸｼｮﾝ!", "Σ", "∑", "嫌ー！"]
      true

    @addResonance /抹茶村/, (text, cb)->
      false

    @addResonance /抹茶/, (text, cb) ->
      cb util.randArray ["抹茶おいしい！抹茶！", "！！", "ぽよ", "にゃーん", "抹茶", "matcha"]
      true

    @addResonance /嫌ー+[!！]+/, (text, cb)->
      cb util.randArray ["嫌ー！", "嫌ー！！", "嫌ー！嫌ー！！"]
      true

    @connect()

    setInterval =>
      @createTweet (text)=> @action.emit 'tweet', text: text
    , 1800000

  reconnect: ->
    @connect()

  procTweet: (data)->
    return if data.user.id is @self_id
    isMention = if data.status.mentions.length is 0 then false else (data.status.mentions[0].id_str is @self_id)
    isRetweet = data.status.isRetweet
    isRetweet2 = new RegExp(/(R|Q)T @[^\s　]+/g).test data.status.text
    isLink = if data.status.urls.length is 0 then false else true
    isHashtag = if data.status.hashtags.length is 0 then false else true
    isBot = [data.user.screen_name, data.user.user_name, data.status.via].some (v)-> new RegExp(/bot/i).test(v)
    isBot = false if new RegExp(/tweetbot/i).test data.status.via
    isIgnore = [
      /Tweet Button/i
      /ツイ廃あらーと/i
      /ツイート数カウントくん/i
      /リプライ数チェッカ/i
      /twittbot/i
      /twirobo/i
      /EasyBotter/i
      /makebot/i
      /botbird/i
      /botmaker/i
      /autotweety/i
      /rekkacopy/i
      /ask\.fm/i
    ].some (v)-> new RegExp(v).test data.status.via

    urls = []
    tags = []

    data.status.text = @preReplace data.status.text, data.user.screen_name

    return if isIgnore
    return if isRetweet or isRetweet2
    return if isBot

    if isMention
      for command in @commands
        if command.regex.test data.status.text
          command.callback data.user.screen_name, data.status.text, (text)=>
            @action.emit 'reply',
              status_id: data.status.id
              screen_name: data.user.screen_name
              text: text
          return

      token = @tokenize data.status.text
      for res in @response
        if res.regex.test data.status.text
          return if res.callback data.user.screen_name, data.status.text, token, (res)=>
            @action.emit 'reply',
              status_id: data.status.id
              screen_name: data.user.screen_name
              text: res

      return

    for res in @resonance
      if res.regex.test data.status.text
        return if res.callback data.status.text, (res)=>
          @action.emit 'tweet', text: res
          @action.emit 'favorite', status_id: data.status.id

    return if data.user.protected or data.status.text.length < 4

    if isLink
      data.status.text = data.status.text.replace /https*:[^\s　]+/g, ""
      urls = _.map data.status.urls, 'url'
      _.forEach urls, (url)->
        encodedUrl = encodeURIComponent url
        console.log "isLink: #{encodedUrl}".red

    if isHashtag
      data.status.text = data.status.text.replace /#[^\s　]+/g, ""
      tags = _.map data.status.hashtags, 'text'
      _.forEach tags, (tag)->
        encodedTag = encodeURIComponent "##{tag}"
        console.log "isTag: #{encodedTag}".red

    parts = _.map @tokenize(data.status.text), 'surface'
    @storeTweet parts


  storeTweet: (parts)->
    return
    return if parts.length < 3
    ###
    parts = _.map parts, (v)-> encodeURIComponent(v)
    current = ['__first__', '__first__', '']

    _.forEach parts, (v)->
      current[2] = v
      tweetDS.push
        first: current[0]
        second: current[1]
        third: current[2]
      current[0] = current[1]
      current[1] = current[2]

    tweetDS.push
      first: current[0]
      second: current[1]
      third: '__end__'
    tweetDS.push
      first: current[1]
      second: '__end__'
      third: '__end__'###

  createResponse: (text, token, cb)->
    return cb text

  createTweet: (cb)->
    return cb "ポ"
    ###recur = (key, i, res)->
      return cb(res.slice(0, 140)) if res.length > 140
      return cb(res) if i > 20
      flag = false
      tweetDS.query(first: key).limit(1000).done (data)->
        if flag
          logger.warn "CALLED CALLBACK TWO TIMES !!"
          return
        flag = true
        console.log key, data.length
        return cb(res) unless data.length

        parts = util.randArray data

        if parts.third is '__end__'
          res = "#{res}#{decodeURIComponent parts.second}" if parts.second isnt '__end__'
          return cb res

        res = "#{res}#{decodeURIComponent parts.second}" if parts.second isnt '__first__'
        recur parts.third, i + 1, "#{res}#{decodeURIComponent parts.third}"

    recur '__first__', 0, ""###

  procActivity: (data)->

  procDM: (data)->

  procFollow: (data)->

  procDelete: (data)->

  procUserUpdate: (data)->

  preReplace: (text, screen_name = "null")->
    text = text
      .replace new RegExp(/&quot;/g), '"'
      .replace new RegExp(/&lt;/g), '<'
      .replace new RegExp(/&gt;/g), '>'
      .replace new RegExp(/&amp/g), '&'
      .replace new RegExp(/(@|＠)[^\s　]+/g), ''
      .replace new RegExp(/^[\s　]+/), ''
      .replace new RegExp(/[\s　]+$/), ''
      .replace new RegExp(/%at%/g), '@'
      .replace new RegExp(/%me%/g), '@' + screen_name

  afterReplace: (text, screen_name)->
    text
  
  addCommand: (regex, cb)->
    @commands.push
        regex: regex
        callback: cb

  addResponse: (regex, cb)->
    @response.push
        regex: regex
        callback: cb

  addResonance: (regex, cb)->
    @resonance.push
        regex: regex
        callback: cb


# kuromoji
kuromoji.builder(dicPath: KUROMOJI_DIC_DIR).build (err, tokenizer)->
  return logger.error err if err

  keymap =
    "surface_form": "surface"
    "pos": "type"
    "pos_detail_1": "type1"
    "pos_detail_2": "type2"
    "pos_detail_3": "type3"
    "basic_form": "base"
    "reading": "reading"
    "conjugated_form": "conj"

  analyzer = (text)->
    _.map tokenizer.tokenize(text), (obj)->
      #console.log obj
      _.transform obj, (res, v, k)->
        res[keymap[k]] = v if _.has(keymap, k)

  bot = new TwitterBot tw_client, analyzer
  bot.start()

# uncaughtException
process.on 'uncaughtException', (err)->
  logger.error err.stack
