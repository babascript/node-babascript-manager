_ = require 'lodash'
hat = require 'hat'

module.exports = (app) ->
  {User} = app.get "models"
  {Task} = app.get "models"
  {Device} = app.get "models"
  {Notification} = app.get 'helper'
  linda = app.get "linda"

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
          token: hat()
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
      if err or !user?
        res.send 400
      else
        collection = []
        data = user.attribute || {}
        collection.push {key: "username", value: user.username}
        _.each data, (v, k) ->
          return if v is null
          collection.push {key: k, value: v}
        res.send 200, collection

  app.put "/api/user/:name/attributes/:key", (req, res, next) ->
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
            linda.tuplespace(user.username).write
              type: 'userdata'
              username: user.username
              key: key
              value: value

  app.del "/api/user/:name/attributes/:key", (req, res, next) ->
    username = req.params.name
    key = req.params.key
    User.findOne {username: username}, (err, user) ->
      if err
        res.send 400
      else
        user.attribute[key] = null
        user.markModified 'attribute'
        user.save (err) ->
          if err
            res.send 400
          else
            res.send 200

  app.get '/api/user/:name/tasks', (req, res, next) ->
    name = req.params.name
    Task.find({worker: name})
    .sort('-createdAt').exec (err, tasks) ->
      if err
        res.send 400
      else
        res.send 200, tasks


  app.get '/api/users', (req, res, next) ->
    names = req.body.names
    if !_.isArray(names) then names = [names]
    User.find {username: {$in: names}}, (err, users) ->
      if err or users.length is 0
        res.send 400
      else
        res.send 200, users

  app.get '/api/users/all', (req, res, next) ->
    User.find {}, (err, users) ->
      if err
        res.send 400
      else
        res.send 200, users

  app.put "/api/user/:name/token", (req, res, next) ->
    User.findOne {username: req.params.name}, (err, user) ->
      if err
        res.send 400
      else
        user.token = hat()
        user.save (err) ->
          if err
            res.send 400
          else
            res.send 200, {token: user.token, username: user.username}

  app.get "/api/user/:name/device", (req, res, next) ->
    User.findOne({username: req.params.name}).populate("device")
    .exec (err, user) ->
      if err
        res.send 400
      else
        res.send 200, user

  app.post "/api/user/:name/device", (req, res, next) ->
    token = req.body.token
    type = req.body.type
    User.findOne {username: req.params.name}, (err, user) ->
      if err
        res.send 400
      else
        device = new Device()
        device.token = req.body.token
        device.type = req.body.type
        device.save (err) ->
          if err
            res.send 400
          else
            console.log device
            user.device = device._id
            user.devicetoken = token
            user.devicetype = type
            user.save (err) ->
              if err
                res.send 400
              else
                res.send 200, device

  app.get "/api/user/:name/notify", (req, res, next) ->
    User.findOne {username: req.params.name}, (err, user) ->
      if err
        res.send 400
      else
        token = user.devicetoken
        type = user.devicetype
        Notification.sendNotification type, token, "こんばんわー！！"
        res.send 200
