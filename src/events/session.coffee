passport = require 'passport'
LocalStrategy = require('passport-local').Strategy
module.exports = (app) ->
  {User} = app.get "models"
  passport.serializeUser (user, done) ->
    done null, user._id
  passport.deserializeUser (id, done) ->
    User.findOne {_id: id}, (err, user) ->
      done null, user

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

  app.get "/api/session", (req, res, next) ->
    console.log req.session
    if req.session?.passport?.user?
      res.send 200, true
    else
      res.send 401

  app.get "/api/session/logout", (req, res, next) ->
    req.logOut()
    res.send 200

  app.get '/api/session/success', (req, res, next) ->
    res.send 200, true

  app.get '/api/session/failure', (req, res, next) ->
    res.send 401
