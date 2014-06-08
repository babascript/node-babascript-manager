_ = require 'lodash'

module.exports = (app) ->
  {User} = app.get "models"

  app.post "/api/user/new", (req, res, next) ->
    username = req.body.username
    password = req.body.password
    User.findOne {username: username}, (err, user) ->
      throw err if err
      if user?
        res.send 404
      else
        user = new User
          username: username
          password: password
        user.save (err) ->
          if err
            res.send 404
          else
            res.send 201, user

  app.get "/api/user/:name", (req, res, next) ->
    username = req.params.name
    User.findOne {username: username}, (err, user) ->
      if err or !user?
        res.send 404
      else
        res.send 200, user

  # app.put "/api/user/:name", (req, res, next) ->
  #   username = req.body.username
  #   User.findOne {username: username}, (err, user) ->
  #

  app.del "/api/user/:name", (req, res, next) ->
    username = req.params.name
    password = req.body.password
    User.findOne {username: username}, (err, user) ->
      if err or !user?
        res.send 400
      else
        user.comparePassword password, (err, isMatch) ->
          if err or !isMatch
            res.send 400
          else
            user.remove (err, p) ->
              if err
                res.send 400
              else
                res.send 200

  app.get "/api/user/:name/attributes", (req, res, next) ->
    username = req.params.name
    User.findOne {username: username}, (err, user) ->
      if err
        res.send 400
      else
        collection = []
        data = user.attribute
        collection.push {key: "username", value: user.username}
        _.each data, (v, k) ->
          return if v is null
          collection.push {key: k, value: v}
        res.send 200, collection

  app.put "/api/user/:name/attributes", (req, res, next) ->
    username = req.params.name
    {key, value} = req.body
    User.findOne {username: username}, (err, user) ->
      if err
        res.send 400
      else
        user.attribute[key] = value
        user.markModified('attribute')
        user.save (err) ->
          if err
            res.send 400
          else
            res.send 200

  app.del "/api/user/:name/attribtues", (req, res, next) ->
    username = req.params.name
    key = req.body.key
    User.findOne {username: username}, (err, user) ->
      if err
        res.send 400
      else
        user.attribute[key] = null
        user.save (err) ->
          if err
            res.send 400
          else
            res.send 200
