oauth = require 'oauth'
events = require 'events'
http = require 'http'
qs = require 'querystring'

### twitter ###
class Twitter
	constructor: (@server, oauth_version, @consumer_key, @consumer_secret, @access_token, @access_token_secret) ->
		if oauth_version is '1.0A'
			@oa = new oauth.OAuth "https://api.twitter.com/oauth/request_token", "https://api.twitter.com/oauth/access_token", @consumer_key, @consumer_secret, "1.0A", "http://#{@server.get 'ipaddr'}:#{@server.get 'port'}/auth/twitter/callback", "HMAC-SHA1"
			# http://#{@server.get 'ipaddr'}:#{@server.get 'port'}/auth/twitter/callback"
			# oob
			unless @access_token? and @access_token_secret?
				@login()
				#@login2 7723661, "SODcaxzTnGytNdis6NplCxxDVtyKAd34ox3aDzoYw", "tlmM6YA7u3TXc1NPhw2E1Uqx2uuxERk3keK0PC04"
		else
			throw new Error "Sorry, this OAuth version is unsupported."

	login : ()->
		@server.get '/auth/twitter', (req, res)=>
			@oa.getOAuthRequestToken (error, oauth_token, oauth_token_secret, results)->
				if error
					console.log error
					res.send "Error."
				else
					req.session.oauth = {}
					req.session.oauth.twitter = {}
					req.session.oauth.twitter.token = oauth_token;
					req.session.oauth.twitter.token_secret = oauth_token_secret
					console.log "oauth.twitter.token: #{req.session.oauth.twitter.token}"
					console.log "oauth.twitter.token_secret: #{req.session.oauth.twitter.token_secret}"
					res.redirect "https://twitter.com/oauth/authenticate?oauth_token=#{oauth_token}"

		@server.get '/auth/twitter/callback', (req, res, next)=>
			if req.session.oauth?.twitter?
				@server.routes.get = @server.routes.get.filter (v)-> v.path isnt "/auth/twitter/callback"
				req.session.oauth.twitter.verifier = req.query.oauth_verifier
				oauth = req.session.oauth.twitter
				@oa.getOAuthAccessToken oauth.token, oauth.token_secret, oauth.verifier, (error, oauth_access_token, 	oauth_access_token_secret, results)=>
					if error
						console.log error
						res.send "Error."
					else
						req.session.oauth.twitter.access_token = oauth_access_token
						req.session.oauth.twitter.access_token_secret = oauth_access_token_secret
						@access_token = oauth_access_token
						@access_token_secret = oauth_access_token_secret
						console.log "oauth_access_token : #{oauth_access_token}"
						console.log "oauth_access_token_secret : #{oauth_access_token_secret}"
						console.log results
						res.redirect "http://#{@server.get 'ipaddr'}:#{@server.get 'port'}"
			else
				next new Error("unexpected error. please retry.")

	login1 : ()->
		@server.get '/auth/twitter', (req, res)=>
			@oa.getOAuthRequestToken (error, oauth_token, oauth_token_secret, results)->
				if error
					console.log error
					res.send "Error."
				else
					req.session.oauth = {}
					req.session.oauth.twitter = {}
					req.session.oauth.twitter.token = oauth_token;
					req.session.oauth.twitter.token_secret = oauth_token_secret
					console.log "oauth.twitter.token: #{req.session.oauth.twitter.token}"
					console.log "oauth.twitter.token_secret: #{req.session.oauth.twitter.token_secret}"
					res.redirect "https://twitter.com/oauth/authenticate?oauth_token=#{oauth_token}"

	login2 : (pin, oauth_token, oauth_token_secret)->
		@server.get '/auth/twitter/callback', (req, res, next)=>
			@server.routes.get = @server.routes.get.filter (v)-> v.path isnt "/auth/twitter/callback"
			@oa.getOAuthAccessToken oauth_token, oauth_token_secret, pin, (error, oauth_access_token, oauth_access_token_secret, results)=>
				if error
					console.log error
					res.send "Error."
				else
					@access_token = oauth_access_token
					@access_token_secret = oauth_access_token_secret
					console.log "oauth_access_token : #{oauth_access_token}"
					console.log "oauth_access_token_secret : #{oauth_access_token_secret}"
					console.log results
					res.redirect "http://#{@server.get 'ipaddr'}:#{@server.get 'port'}"

	userstream : (params, callback) =>
		if typeof params is 'function'
			callback = params
			param = null
		@stream = new events.EventEmitter
		buffer = ""
		req = @oa.post "https://userstream.twitter.com/1.1/user.json", @access_token, @access_token_secret, params
		req.on 'response', (res) =>
			res.on 'data', (chunk) =>
				buffer += chunk.toString 'utf8'
				data = buffer.split "\r\n"
				return if data.length < 2
				if data[data.length-1].length is 0
					buffer = ""
				else
					buffer = data[data.length-1]
					data[data.length-1] = ""
				data = data.filter (v)-> v.length > 0
				data.forEach (v) =>
					try
						json = JSON.parse v
						@stream.emit 'data', json
					catch e
						@stream.emit 'error', e
			res.on 'error', (error) =>
				@stream.emit 'error', error
			res.on 'end', () =>
				@stream.emit 'end', res
		req.on 'error', (error) =>
			@stream.emit 'error', error
		req.end()
		callback @stream

	get : (url, params, callback) ->
		if typeof params is 'function'
			callback = params
			params = null
		url = "https://api.twitter.com/1.1#{url}" if url.charAt(0) is '/'
		@oa.get "#{url}?#{qs.stringify params}", @access_token, @access_token_secret, (err, data, res) =>
			if err
				error = new Error "HTTP Error #{err.statusCode}: #{http.STATUS_CODES[err.statusCode]}"
				error.statusCode = err.statusCode
				error.data = err.data
				callback error, null
			else
				try
					json = JSON.parse data
					@processError json, callback
				catch e
					callback e, null

	post : (url, content, content_type, callback) ->
		if typeof content is 'function'
			callback = content
			content = null
			content_type = null
		else if typeof content_type is 'function'
			callback = content_type
			content_type = null
		if content and typeof content is 'object'
			for key of content
				content[key] = content[key].toString() if typeof content[key] is 'boolean'
		url = "https://api.twitter.com/1.1#{url}" if url.charAt(0) is '/'
		@oa.post url, @access_token, @access_token_secret, content, content_type, (err, data, res) =>
			if err
				error = new Error "HTTP Error #{err.statusCode}: #{http.STATUS_CODES[err.statusCode]}"
				error.statusCode = err.statusCode
				error.data = err.data
				callback error, null if callback?
			else
				try
					json = JSON.parse data
					@processError json, callback
				catch e
					callback e, null if callback?

	processError : (data, callback) ->
		if data.data
			try
				err = JSON.parse data.data
				error = new Error "[error] #{err.errors[0].code}-#{err.errors[0].message}"
				error.statusCode = err.errors[0].code
				error.data = err.errors[0].message
				callback error, null if callback?
			catch e
				callback e, null  if callback?
		else
			callback null, data if callback?

	escape: (text)->
		text = text.replace /</g, "&lt;"
		text = text.replace />/g, "&gt;"
		text = text.replace /&/g, "&amp;"
		text

	descape: (text)->
		text = text.replace /&amp;/g, "&"
		text = text.replace /&lt;/g, "<"
		text = text.replace /&gt;/g, ">"
		text

	parseUserData: (user)->
		obj =
			screen_name: user.screen_name
			name: user.name
			id: user.id_str
			protected: user.protected
			tweet_count: user.statuses_count
			fav_count: user.favourites_count
		obj

	parseStatusData: (data)->
		obj =
			id: data.id_str
			text: @descape data.text
			hashtags: data.entities.hashtags
			urls: data.entities.urls
			mentions: data.entities.user_mentions
			reply_user_id: data.in_reply_to_user_id_str
			reply_status_id: data.in_reply_to_status_id_str
			date: new Date(data.created_at).getTime()
			via: data.source.replace new RegExp(/<[^>]+>/g),''
		obj.isRetweet = data.retweeted_status?
		obj

	parseData: (data)->
		obj = {}
		if data.event?
			if (data.event is 'favorite') or (data.event is 'unfavorite')
				obj =
					type: data.event
					source: @parseUserData data.source
					target: @parseUserData data.target
					status: @parseStatusData data.target_object

			else if (data.event is 'follow') or (data.event is 'unfollow')
				obj =
					type: data.event
					source: @parseUserData data.source
					target: @parseUserData data.target
			else if data.event is 'user_update'
				obj =
					type: data.event
					user: @parseUserData data.source
			else
				obj = data
		else if data.text?
			obj =
				type: 'tweet'
				user: @parseUserData data.user
				status: @parseStatusData data
		else if data.direct_message?
			data = data.direct_message
			obj =
				type: 'direct_message'
				source: @parseUserData data.sender
				target: @parseUserData data.recipient
				status:
					id: data.id_str
					text: data.text
					date: new Date(data.created_at).getTime()
		else if data.friends?
			obj =
				type : 'friend'
				data : data.friends
		else if data.delete?
			obj =
				type: 'delete'
				user_id: data.delete.status.user_id_str
				status_id: data.delete.status.id_str
		else
			obj = data
		obj

	tweet : (text, params, callback) ->
		if typeof params is 'function'
			callback = params
			params = {}
		params = {} unless params?
		unless new RegExp(/http/).test(text)
			text = text.slice 0, 140
		params.status = text
		@post '/statuses/update.json', params, callback

	reply : (screen_name, text, status_id, params, callback) =>
		if typeof params is 'function'
			callback = params
			params = {}
		params = {} unless params?
		params.in_reply_to_status_id = status_id
		@tweet "@#{screen_name} #{text}", params, callback

	favorite : (status_id, callback) ->
		@post '/favorites/create.json', {id : status_id}, callback

	unfavorite : (status_id, callback) ->
		@post '/favorites/destroy.json', {id : status_id}, callback



module.exports = Twitter