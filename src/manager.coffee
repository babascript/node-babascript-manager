mongoose = require 'mongoose'
_ = require 'underscore'
Crypto = require 'crypto'
LindaSocketIO = require('linda-socket.io')
LocalStrategy = require('passport-local').Strategy
express = require 'express'
passport = require 'passport'
async = require 'async'
redis = require('redis').createClient()
direquire = require 'direquire'
path = require 'path'

Linda = LindaSocketIO.Linda
TupleSpace = LindaSocketIO.TupleSpace

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
      headers += 'X-Requested-With, Origin'
      methods = 'POST, PUT, GET, DELETE, OPTIONS'
      res.setHeader 'Access-Control-Allow-Origin', req.headers.origin
      res.setHeader 'Access-Control-Allow-Credentials', true
      res.setHeader 'Access-Control-Allow-Methods', methods
      res.setHeader 'Access-Control-Request-Method', methods
      res.setHeader 'Access-Control-Allow-Headers', headers
      next()

    @app.set 'events', direquire path.resolve 'src', 'events'
    @app.set 'models', direquire path.resolve 'src', 'models'
    @app.set 'helper', direquire path.resolve 'src', 'helper'
    @app.set 'linda', @linda

    (require path.resolve 'src/events', 'user')(@app)
    (require path.resolve 'src/events', 'group')(@app)

    (require path.resolve 'src/events', 'websocket')(@app)

    if options?.secure? is true
      console.log 'set passport'
      (require path.resolve 'src/events', 'session')(@app)


module.exports = new BabascriptManager()
