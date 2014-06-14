'use strict'

path = require 'path'
http = require 'http'
express = require 'express'
passport = require 'passport'
mongoose = require 'mongoose'
direquire = require 'direquire'

pkg = require path.resolve 'package.json'
app = module.exports = express()

mongoose.connect "mongodb://localhost/#{pkg.name}"

app.set 'helper', direquire path.resolve 'src', 'helper'
app.set 'models', direquire path.resolve 'src', 'models'
app.set 'events', direquire path.resolve 'src', 'events'
app.set 'view engine', 'jade'
app.use (require 'morgan')('dev') if 'off' isnt process.env.NODE_LOG
app.use express.static path.resolve 'public'
app.use (require 'body-parser')()
app.use (require 'method-override')()
app.use (require 'cookie-parser')()
app.use (req, res, next) ->
  app.locals.req = req
  app.locals.pkg = pkg
  return next null

app.set 'manager-client-address', 'http://localhost:9000'

server = app.listen(9080)
io = require('socket.io').listen server
manager = require(path.resolve 'src', 'manager')
manager.attach {io: io, app: app, server: server, secure: true}

# (require path.resolve 'src/events', 'user')(app)
# (require path.resolve 'src/events', 'group')(app)

# if 'development' is process.env.NODE_ENV
#   app.get /^\/assets\/.*?/, (req, res) ->
#     res.stream req.url

# app.listen()
