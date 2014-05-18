mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/babascript/manager'
_ = require 'underscore'
Crypto = require 'crypto'
LindaSocketIO = require('linda-socket.io')
Linda = LindaSocketIO.Linda
TupleSpace = LindaSocketIO.TupleSpace
express = require 'express'
passport = require 'passport'
LocalStrategy = require('passport-local').Strategy

class BabascriptManager

  attach: (@io, @server, @app) ->
    throw new Error 'io not found' if !@io?
    throw new Error 'server not found' if !@server?
    throw new Error 'app not found' if !@app?
    @linda = Linda.listen {io: io, server: server}
    @linda.io.on 'connection', (socket)=>
      socket.on 'disconnect', @Socket.disconnect
      socket.on '__linda_write', @Socket.write
      socket.on '__linda_take', @Socket.take
      socket.on '__linda_cancel', @Socket.cancel
    passport.serializeUser (user, done) ->
      console.log 'serializeUser'
      console.log user
      username = user.get 'username'
      done null, user
    passport.deserializeUser (username, done) ->
      console.log 'deserializeUser'
      console.log username
      done err, username
    passport.use(new LocalStrategy (username, password, done) =>
      data =
        username: username
        password: password
      @login data, (err, user) ->
        return done err if err
        console.log "localStrategy"
        console.log user
        if !user
          done null, null, {message: 'invalid user'}
        else
          done null, user
    )
    @app.use passport.initialize()
    @app.use passport.session()
    auth =
      passport.authenticate 'local',
        successRedirect: '/'
        failureRedirect: '/api/session/failure'
        failureFlash: false
    @app.post '/api/session/login', (req, res, next) ->
      auth(req, res, next)
    @app.get '/api/session', (req, res, next) ->
      if req.session.passport.user?
        res.send 200
      else
        res.send 500
    @app.get '/api/session/success', (req, res, next) ->
      res.send 200
      return res.end()
    @app.get '/api/session/failure', (req,res, next) ->
      console.log 'failure'
      res.send 500
    @app.post '/api/user/new', (req, res, next)=>
      console.log req.body
      username = req.param 'username'
      password = req.param 'password'
      attrs = {username: username, password: password}
      console.log attrs
      @createUser attrs, (err, user) ->
        throw err if err
        res.send 200
    @app.get  '/api/user/:name', (req, res, next)=>
      @getUser req.params.name, (err, user) ->
        if err
          res.send 500
        else
          res.json 200, user
    @app.put  '/api/user/:name', (req, res, next) ->
      res.send 200
    @app.delete '/api/user/:name', (req, res, next) ->
      res.send 200
    @app.post '/api/group/new', (req, res, next) ->
      res.send 200
    @app.get  '/api/group/:name', (req, res, next) ->
      res.send 200
    @app.put  '/api/group/:name', (req, res, next) ->
      res.send 200
    @app.delete '/api/group/:name', (req, res, next) ->
      res.send 200

  # return status, user
  createUser: (attrs, callback) ->
    username = attrs.username
    password = attrs.password
    User.create username, password, (err, user) ->
      if err
        return callback err, null
      if !user?
        error = new Error 'user not found'
        return callback error, user
      else
        return callback null, user

  # return user of null
  getUser: (username, callback) ->
    User.find username, callback

  createGroup: (attrs, callback) ->
    owner = attrs.owner
    return callback false, null if !owner? or !owner.isAuthenticate
    Group.create attrs, (status, group) ->
      if !group?
        return callback false, null
      else
        return callback true, group

  getGroup: (attrs, callback) ->
    Group.find attrs, callback

  login: (attrs, callback) ->
    User.login attrs, (err, user) ->
      throw err if err
      callback null, user


class BBObject
  data: {}
  __data: {}

  save: (callback) ->
    if !@data? or !@__data?
      error = new Error 'data is undefined'
      callback error, null
    else
      @data.save (err)=>
        if err
          @data = @__data
          error = new Error 'save error'
          callback.call @, err
        else
          @__data = _.clone @data
          callback.call @, null

  set: (key, value) ->
    if !(typeof key is 'string') and !(typeof key is 'number')
      throw new Error 'key should be String or Number'
    @data[key] = value

  get: (key) ->
    if (typeof key isnt 'string') and (typeof key isnt 'number')
      throw new Error 'key should be String or Number'
    return @data[key]


class User extends BBObject
  isAuthenticate: false
  username: ''
  password: ''
  groups: []
  devices: []

  @find = (username, callback) ->
    throw new Error "username is undefined" if !username
    u = new User()
    UserModel.findOne {username: username}, (err, user) ->
      throw err if err
      if !user
        error = new Error "user not found"
        return callback error, null
      else
        u.data = user
        u.__data = _.clone u.data
        u.isAuthenticate = false
        return callback.call u, null, u

  @authenticate = (username, password,callback) ->
    throw new Error "username is undefined" if !username
    throw new Error "password is undefined" if !password
    UserModel.findOne {username: username, password: password}, (err, user) ->
      throw err if err
      return callback null if !user
      u = new User()
      u.isAuthenticate = true
      u.data = user
      u.__data = _.clone u.data
      return callback u

  @create = (username, password, callback) ->
    throw new Error "username is undefined" if !username
    throw new Error "password is undefined" if !password
    UserModel.findOne {username: username}, (err, user) ->
      throw err if err
      if user
        error = new Error "already user exist"
        callback.call user, error, user
      else
        u = new User()
        pass = Crypto.createHash("sha256").update(password).digest("hex")
        u.data = new UserModel()
        u.data.username = username
        u.data.password = pass
        u.isAuthenticate = true
        u.save (err) ->
          callback.call u, err, u

  @login = (attrs, callback) ->
    username = attrs.username
    password = attrs.password
    throw new Error "username is undefined" if !username
    throw new Error "password is undefined" if !password
    pass = Crypto.createHash("sha256").update(password).digest("hex")
    UserModel.findOne {username: username, password: pass}, (err, user) ->
      throw err if err
      return callback new Error("authenticate failed"), null if !user?
      u = new User()
      u.data = user
      u.isAuthenticate = true
      callback null, u

  authenticate: (password,callback) ->
    username = @get("username")
    throw new Error "username is undefined" if !username?
    throw new Error "password is undefined" if !password?
    p = Crypto.createHash("sha256").update(password).digest("hex")
    UserModel.findOne {username: username, password: p}, (err, user)=>
      throw err if err
      return callback false if !user?
      @isAuthenticate = true
      callback.call @, @isAuthenticate

  save: (callback) ->
    if !@isAuthenticate
      error = new Error "ERROR: user isn't authenticated"
      @data = @__data
      return callback.call @, error
    super callback
  #   if !@isAuthenticate
  #     @data = @__data
  #     return callback.call @, false
  #   @data.save (err)=>
  #     if err
  #       @data = @__data
  #       callback.call @, err
  #     else
  #       @__data = @data
  #       callback.call @, null

  # set: (name, data) ->
  #   return false if !data?
  #   @data[name] = data

  # get: (name) ->
  #   return @data[name]

  # delete: (username, password, callback) ->
  #   return callback false if !@isAuthenticate
  #   p = Crypto.createHash("sha256").update(password).digest("hex")
  #   UserModel.findOne {username: username, password: p}, (err, user) ->
  #     throw err if err
  #     console.log user
  #     return callback false if !user?
  #     user.remove()
  #     user.save (err) ->
  #       callback true

  delete: (callback) ->
    return callback new Error("not authenticated"), false if !@isAuthenticate
    @data.remove (err, user) ->
      throw err if err
      callback null, true

  addGroup: (name, callback) ->
    return callback false if !@data
    GroupModel.findOne {name: name}, (err, group)=>
      throw err if err
      return callback false if !group
      g = _.find @data.groups, (group) ->
        return group.name is name
      @data.groups.push group._id if !g
      @data.save (err) ->
        throw err if err
        member = _.find group.members, (m) ->
          return m._id is @data._id
        group.members.push @data._Id if !member
        group.save (err) ->
          throw err if err
          callback @data
    #   UserModel.findOne {username: @get("username")}, (err, user) ->
    #     throw err if err
    #     return callback false if !user

    # group = _.find @data.groups, (group) ->
    #   return group.name is name
    # return callback false if group
    # group = new Group()
    # group.find (g) ->
    #   if !g
    #     group.name = name
    #     group.members = []
    #     group.save (err) ->
    #       throw err if err
    #       user.groups.push group
    #       user.save (err) ->
    #         throw err if err
    #         callback group
    #   else
    #     user.groups.push g
    #     user.save (err) ->
    #       throw err if err
    #       callback g

  removeGroup: (name, callback) ->
    return callback false if !@data or !@username
    GroupModel.findOne {name: name}, (err, group) ->
      throw err if err
      UserModel.findOne {username: @username}, (err, user) ->
        throw err if err
        for i in [0..user.groups.length-1]
          user.groups.split i, 1 if user.groups[i].name is name
        user.save (err) ->
          throw err if err
          callback true

  getDevice: (uuid, callback) ->
    if @data
      callback @data, @data.device
    else
      @find {username: @username}, (err, user) ->
        throw err if err
        callback user, user.device

  addDevice: (device, callback) ->
    @getDevice device.uuid, (user, device) ->
      return true if device
      device = new DeviceModel()
      device.uuid = device.uuid
      device.type = device.type
      device.token = device.token
      device.endpoint = device.endpoint
      device.owner = user._id
      device.save (err) ->
        throw err if err
        user.device = device
        user.save (err) ->
          throw err if err
          callback device

  removeDevice: (uuid, callback) ->
    @getDevice uuid, (user, device) ->
      return false if !device
      user.device = null
      user.save (err) ->
        throw err if err
        callback true

  changePassword: (newpassword, callback) ->
    return callback false if !@isAuthenticate
    return callback false if !@data?
    p = Crypto.createHash("sha256").update(newpassword).digest "hex"
    @data.password = p
    @data.save (err) ->
      throw err if err
      callback true

  changeTwitterAccount: (newAccount, callback) ->
    return callback false, null if !@isAuthenticate
    username = @get "username"
    @set "twitter", newAccount
    @save (user) ->
      callback true, user

  changeMailAddress: (newAddress, callback) ->
    return callback false, null if !@isAuthenticate
    @set "mail", newAddress
    @save (user) ->
      callback true, user

class Group extends BBObject
  data: {}
  __data: {}
  constructor: ->

  @create = (attrs, callback) ->
    throw new Error "name is undefined" if !attrs.name
    throw new Error "owner is undefined" if !attrs.owner
    GroupModel.findOne {name: attrs.name}, (err, group) ->
      throw err if err
      if group
        error = new Error "group is existed"
        return callback.call group, error, group if group
      group = new Group()
      group.data = new GroupModel()
      group.data.name = attrs.name
      group.data.owners.push attrs.owner.data._id
      group.data.members = []
      if attrs.members
        for member in attrs.members
          group.data.members.push member._id
      group.save ->
        return callback.call group, null, group

  @find = (attrs, callback) ->
    name = attrs.name
    throw new Error "name is undefined" if !name
    GroupModel.findOne {name: name}, (err, group) ->
      throw err if err
      if !group
        error = new Error "group not found"
        return callback error, null
      g = new Group()
      g.data = group
      g.__data = _.clone g.data
      return callback.call g, null, g

  fetch: (callback) ->
    return false if !@groupname or !@data
    GroupModel.findOne {name: @groupname}, (err, group)=>
      throw err if err
      callback false if !group
      @data.name = group.name
      @data.members = group.members
      callback @data

  delete: (callback) ->
    GroupModel.findOne {name: @get("name")}, (err, group) ->
      throw err if err
      callback false if !group
      group.remove()
      callback true

  addMembers: (names, callback) ->
    UserModel.find {username: {$in: names}}, (err, users)=>
      throw err if err
      return callback null if !users
      ids = _.pluck users, "_id"
      members = _.pluck @data.members, "_id"
      newMembers = _.union ids, @data.members

  addMember: (user, callback) ->
    throw new Error "arg[0] user is undefined" if !user
    id = user.get "_id"
    UserModel.findById id, (err, user)=>
      throw err if err
      return callback null if !user
      member = _.find @data.members, (m) ->
        return m.toString() is user._id.toString()
      @data.members.push id if !member
      @data.save (err)=>
        return callback err, null if err
        id = @data._id
        group = _.find user.groups, (group) ->
          return group.toString() is id
        user.groups.push id if !group
        user.save (err)=>
          return callback err, null if err
          GroupModel.populate @data, {path: 'members'}, (err, group)=>
            @data = group
            @__data = _.clone @data
            callback.call @, null, @

  removeMember: (user, callback) ->
    throw new Error "arg[0] user is undefined" if !user
    id = user.get "_id"
    UserModel.findById id, (err, user)=>
      throw err if err
      return callback null if !user
      flag = false
      for i in [0..@data.members.length-1]
        if @data.members[i].toString() is user._id.toString()
          @data.members.splice i, 1
          break
      @data.save (err)=>
        throw err if err
        for i in [0..user.groups.length-1]
          if user.groups[i].toString() is @data._id.toString()
            user.groups.splice i, 1
            break
        user.save (err)=>
          throw err if err
          GroupModel.populate @data, {path: "members"}, (err, group)=>
            @data = group
            @__data = _.clone @data
            callback.call @, null, @

  getMembers: (callback) ->
    q = GroupModel.findOne({name: @data.name})
    q.populate("members", "username device")
    q.exec (err, group) ->
      throw err if err
      callback group.members

UserModel = mongoose.model "user", new mongoose.Schema
  username: type: String
  password: type: String
  twitter: type: String
  mail: type: String
  device: type: {type: mongoose.Schema.Types.ObjectId, ref: "device"}
  groups: type: [{type: mongoose.Schema.Types.ObjectId, ref: "group"}]

GroupModel = mongoose.model "group", new mongoose.Schema
  name: type: String
  owners: type: [{type: mongoose.Schema.Types.ObjectId, ref: "user"}]
  members: type: [{type: mongoose.Schema.Types.ObjectId, ref: "user"}]

DeviceModel = mongoose.model "device", new mongoose.Schema
  uuid: type: String
  type: type: String
  token: type: String
  endpoint: type: String
  owner: type: {type: mongoose.Schema.Types.ObjectId, ref: "user"}

module.exports =
  User: User
  Group: Group
  Manager: new BabascriptManager()
