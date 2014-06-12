'use strict'

path = require 'path'
http = require 'http'
express = require 'express'
session = require 'express-session'
passport = require 'passport'
mongoose = require 'mongoose'
direquire = require 'direquire'

pkg = require path.resolve 'package.json'
app = module.exports = express()

RedisStore = (require 'connect-redis')(session)
mongoose.connect "mongodb://localhost/#{pkg.name}_production"

app.set 'helper', direquire path.resolve 'src', 'helper'
app.set 'models', direquire path.resolve 'src', 'models'
app.set 'events', direquire path.resolve 'src', 'events'
app.set 'view engine', 'jade'
app.use (require 'morgan')('dev') if 'off' isnt process.env.NODE_LOG
app.use express.static path.resolve 'public'
app.use (require 'body-parser')()
app.use (require 'method-override')()
app.use (require 'cookie-parser')()
app.use session
  store: new RedisStore {prefix: "sess:#{pkg.name}"}
  secret: 'keyboard cat'
  cookie: expires: no
app.use passport.initialize()
app.use passport.session()
app.use (req, res, next) ->
  app.locals.req = req
  app.locals.pkg = pkg
  return next null

server = app.listen process.env.PORT || 1217
io = require('socket.io').listen server
manager = require(path.resolve 'src', 'manager')
manager.attach {io: io, app: app, server: server, secure: true}

app.listen()
