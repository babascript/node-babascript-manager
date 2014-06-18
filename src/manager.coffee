mongoose = require 'mongoose'
LindaSocketIO = require('linda-socket.io')
LocalStrategy = require('passport-local').Strategy
express = require 'express'
cookie = require 'cookie'
session = require 'express-session'
passport = require 'passport'
direquire = require 'direquire'
path = require 'path'
pkg = require path.resolve 'package.json'

{Linda, TupleSpace} = LindaSocketIO

class BabascriptManager

  constructor: ->
    console.log 'init!'

  attach: (options = {}) ->
    @io = options.io
    @server = options.server || @io.server
    @app = options.app
    throw new Error 'io not found' if !@io?
    throw new Error 'server not found' if !@server?
    throw new Error 'app not found' if !@app?

    @linda = Linda.listen {io: @io, server: @server}

    @app.use (req, res, next) ->
      headers = 'Content-Type, Authorization, Content-Length,'
      headers += 'X-Requested-With, Origin, Accept-Encoding'
      methods = 'POST, PUT, GET, DELETE, OPTIONS'
      res.setHeader 'Access-Control-Allow-Origin', req.headers.origin
      res.setHeader 'Access-Control-Allow-Credentials', true
      res.setHeader 'Access-Control-Allow-Methods', methods
      res.setHeader 'Access-Control-Allow-Headers', "*"
      res.setHeader 'Access-Control-Allow-Accept-Encoding', "gzip"
      res.setHeader 'Access-Control-Request-Method', methods
      res.setHeader 'Access-Control-Allow-Headers', headers
      next()

    RedisStore = (require 'connect-redis')(session)
    @app.use session
      store: new RedisStore {prefix: "sess:#{pkg.name}:"}
      secret: 'keyboard cat'
      cookie: expires: no

    Events =
      Group: require("./events/group")
      Session: require "./events/session"
      User: require "./events/user"
      Websocket: require "./events/websocket"
    Models = require "./models/model"
    Helper =
      Notification: require "./helper/notification"

    @app.set 'events', Events
    @app.set 'models', Models
    @app.set 'helper', Helper
    @app.set 'linda', @linda

    Events.Session @app
    Events.User @app
    Events.Group @app
    Events.Websocket @app

    if options.secure?
      @io.configure =>
        @io.set "authorization", (handshakeData, callback) ->
          console.log 'authorization'
          console.log handshakeData
          token = handshakeData.query?.token
          if handshakeData.headers['user-agent'] is 'node-XMLHttpRequest'
            handshakeData.actor = false
            # handshakeData.user =
            #   username:
            return callback null, true
          if !token?
            return callback 'error', false
          else
            Models.User.findOne {token: token}, (err, user) ->
              throw err if err
              handshakeData.user = user
              if user
                callback null, true
              else
                callback 'token not found', false
# node-client側はどうしよ？
# if handshakeData.headers['user-agent'] is 'node-XMLHttpRequest'
#   return callback null, true
# if handshakeData.headers.cookie?
#   data = handshakeData.headers.cookie
#   sessionID = cookie.parse(data)['connect.sid']
#   PREFIX_LENGTH = 2
#   SESSION_LENGTH = 24
#   sid = sessionID.slice PREFIX_LENGTH, PREFIX_LENGTH + SESSION_LENGTH
#   redisStore.get sid, (err, data) ->
#     return callback 'error', false if err
#     handshakeData.session = data
#     callback null, true
# else
#   callback 'error', false


module.exports = new BabascriptManager()
