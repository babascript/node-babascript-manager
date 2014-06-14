passport = require 'passport'
LocalStrategy = require('passport-local').Strategy
hat = require 'hat'

module.exports = (app) ->
  {User} = app.get "models"
  {Token} = app.get "models"

  passport.serializeUser (user, done) ->
    console.log 'serialize'
    done null, user
  passport.deserializeUser (user, done) ->
    console.log 'deserialize'
    done null, user
    # User.findOne {_id: id}, (err, user) ->
    #   console.log user
    #   done null, user

  passport.use new LocalStrategy (username, password, done) ->
    User.findOne { username: username }, (err, user) ->
      if err then return done(err, false, { message: 'An error occurred.' })
      unless user
        return done(err, false, { message: 'Username not found.' })
      user.comparePassword password, (err, isMatch) ->
        if isMatch
          done err, user
        else
          done null, false, { message: 'Invalid Password' }

  app.use passport.initialize()
  app.use passport.session()
  app.post '/api/session/login', passport.authenticate 'local',
    successRedirect: '/api/session/success'
    failureRedirect: '/api/session/failure'

  app.post '/api/session/__login', (req, res, next) ->


  app.get "/api/session", (req, res, next) ->
    # console.log "GET /api/session"
    console.log req.session
    # console.log req.user
    if req.session?.passport?.user?
      user = req.session.passport.user
      res.send 200,
        username: user.username
        token: user.token
    else
      res.send 401

  app.del "/api/session/logout", (req, res, next) ->
    req.logOut()
    res.send 200

  app.get '/api/session/success', (req, res, next) ->
    res.send 200, true

  app.get '/api/session/failure', (req, res, next) ->
    res.send 401

  app.get '/api/session/token', (req, res, next) ->
    Token.findOne({}, 'token createdAt', {sort: {createdAt: -1}})
    .exec (err, token) ->
      if err
        res.send 400, null
      else
        res.send 200, token

  app.post '/api/session/token', (req, res, next) ->
    token = new Token
      token: hat()
    token.save (err) ->
      if err
        res.send 400, 'generate token is fail'
      else
        res.send 200, token.token
