mongoose = require 'mongoose'
# mongoose.connect 'mongodb://localhost/babascript/manager'
_ = require 'underscore'
Crypto = require 'crypto'
LindaSocketIO = require('linda-socket.io')
LocalStrategy = require('passport-local').Strategy
express = require 'express'
passport = require 'passport'
async = require 'async'

Linda = LindaSocketIO.Linda
TupleSpace = LindaSocketIO.TupleSpace

class BabascriptManager

  attach: (@io, @app) ->
    throw new Error 'io not found' if !@io?
    throw new Error 'server not found' if !@io.server?
    throw new Error 'app not found' if !@app?
    @linda = Linda.listen {io: @io, server: @io.server}
    @linda.io.set 'log lebel', 2
    @linda.io.set 'baba', 'takumi'
    @linda.io.on 'connection', (socket) ->
      socket.on 'disconnect', ->
      socket.on '__linda_write', (data) ->
      socket.on '__linda_take', (data) ->
      socket.on '__linda_cancel', (data) ->
    passport.serializeUser (data, done) ->
      username = data.username
      password = data.password
      u =
        username: username
        password: password
      done null, u
    passport.deserializeUser (data, done) ->
      done null, data
    passport.use(new LocalStrategy (username, password, done) =>
      data =
        username: username
        password: password
      @login data, (err, user) ->
        if err
          done err, null
        else if !user
          done null, null, {message: 'invalid user'}
        else
          done null, data
    )
    @app.use passport.initialize()
    @app.use passport.session()
    auth =
      passport.authenticate 'local',
        successRedirect: '/'
        failureRedirect: '/api/session/failure'
        failureFlash: false
    @app.get '/api/imbaba/:name', (req, res, next) =>
      attr =
        name: req.params.name
      @getGroup attr, (err, group) ->
        if err or !group?
          res.send 400
        else
          members = group.get "members"
          res.send 200, members
    @app.post '/api/session/login', (req, res, next) ->
      auth(req, res, next)
    @app.delete '/api/session/logout', (req, res, next) ->
      delete req.session
      res.send 200
    @app.get '/api/session', (req, res, next) ->
      if req.session.passport.user?
        res.send 200
      else
        res.send 404
    @app.get '/api/session/success', (req, res, next) ->
      res.send 200
    @app.get '/api/session/failure', (req,res, next) ->
      res.send 500
    @app.post '/api/user/new', (req, res, next)=>
      return res.send 404 if !req.session.passport.user?
      username = req.param 'username'
      password = req.param 'password'
      attrs = {username: username, password: password}
      @createUser attrs, (err, user) ->
        if err or !user?
          res.send 404
        else
          res.send 200, user
    @app.get  '/api/user/:name', (req, res, next) =>
      @getUser req.params.name, (err, user) ->
        if err or !user?
          res.send 404
        else
          if req.session.passport.user?.username is user.data?.username
            res.json 200, user
          else
            u =
              data:
                username: user.data.username
            res.json 200, u

    @app.put  '/api/user/:name', (req, res, next) =>
      return res.send 404 if !req.session.passport.user?
      username = req.params.name
      password = req.session.passport.user?.password
      data = req.body
      param =
        username: username
        password: password
      @getUser username, (err, user) ->
        if err or !user?
          res.send 500
        else if req.session.passport.user.username isnt username
          res.send 403
        else
          user.authenticate password, (result) ->
            if !result
              res.send 404
            else
              for key, value of data
                if key is 'password'
                  value = Crypto.createHash("sha256")
                  .update(value).digest("hex")
                user.set key, value
              user.save (err) ->
                throw err if err
                res.send 200

    @app.del '/api/user/:name', (req, res, next) =>
      return res.send 404 if !req.session.passport.user?
      username = req.params.name
      password = req.body.password
      @getUser username, (err, user) ->
        if err or !user?
          res.send 500
        else if req.session.passport.user.username isnt username
          res.send 403
        else
          user.authenticate password, (result) ->
            if !result
              res.send 403
            else
              user.delete (err) ->
                throw err if err
                res.send 200

    @app.post '/api/group/new', (req, res, next) ->
      return res.send 404 if !req.session.passport.user?
      attrs =
        owner: req.body.owner
        name: req.body.name

      @createGroup attrs, (err, group) ->
        if err or !group?
          res.send 404
        else
          res.send 200, group

    @app.get  '/api/group/:name', (req, res, next) =>
      attr =
        name: req.params.name
      @getGroup attr, (err, group) ->
        if err or !group?
          res.send 404, err
        else
          res.send 200, group

    @app.put  '/api/group/:name', (req, res, next) =>
      return res.send 404 if !req.session.passport.user?
      attr =
        name: req.params.name
      data = req.body
      @getGroup attr, (err, group) ->
        if err or !group?
          res.send 404, err
        else
          for key, value of data
            group.set key, value
          group.save (err) ->
            return res.send 404, err if err
            res.send 200

    @app.del '/api/group/:name', (req, res, next) ->
      return res.send 404 if !req.session.passport.user?
      res.send 200

    @app.post '/api/group/:name/member', (req, res, next) =>
      return res.send 404, "not logined" if !req.session.passport.user?
      attr =
        name: req.params.name
      data = req.body
      @getGroup attr, (err, group) ->
        return res.send 404, err if err or !group?
        data =
          groupname: req.params.name
          usernames: req.body.names
        group.addMember data, (err, g) ->
          return res.send 404, err if err or !g?
          return res.send 200, g

    @app.del '/api/group/:name/member', (req, res, next) =>
      return res.send 404, "not logined" if !req.session.passport.user?
      attr =
        name: req.params.name
      data = req.body
      @getGroup attr, (err, group) ->
        return res.send 404, err if err or !group?
        data =
          groupname: req.params.name
          usernames: req.body.names
        group._removeMember data, (err, g) ->
          return res.send 404, err if err or !g?
          return res.send 200, g

    @app.get '/api/group/:name/owner', (req, res, next) ->
    @app.post '/api/group/:name/owner', (req, res, next) =>
      return res.send 404, "not logined" if !req.session.passport.user?
      attr =
        name: req.params.name
      @getGroup attr, (err, group) ->
        return res.send 404, err if err or !group?
        data =
          groupname: req.params.name
          ownernames: req.body.names
        group.addOwner data, (err, g) ->
          return res.send 404, err if err or !g?
          return res.send 200, g
    @app.put '/api/group/:name/owner', (req, res, next) ->
    @app.del '/api/group/:name/owner', (req, res, next) =>
      return res.send 404, "not logined" if !req.session.passport.user?
      attr =
        name: req.params.name
      @getGroup attr, (err, group) ->
        return res.send 404, err if err or !group?
        data =
          groupname: req.params.name
          usernames: req.body.names
        group.removeOwner data, (err, g) ->
          return res.send 404, err if err or !g?
          return res.send 200, g


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
      callback err, user

class BBObject
  data: {}
  __data: {}

  constructor: (attr) ->
    @_serverData = {}
    @isChanged = false

  save: (callback) ->
    return callback.call @, new Error("not change") if !@isChanged
    if !@data? or !@__data?
      error = new Error 'data is undefined'
      callback.call @,  error
    else
      @data.save (err) =>
        if err
          @data = _.clone @__data
        else
          @__data = _.clone @data
        callback.call @, err
        @isChanged = false

  set: (key, value) ->
    if !(typeof key is 'string') and !(typeof key is 'number')
      throw new Error 'key should be String or Number'
    # console.log "SET: attribute key? #{!@data[key]?}: #{key} is #{value}"
    @isChanged = true
    if @data[key]?
      @data[key] = value
    else
      if !@data.attribute?
        @data.attribute = {}
      @data.attribute[key] = value
      @data.markModified 'attribute'

  get: (key) ->
    if (typeof key isnt 'string') and (typeof key isnt 'number')
      throw new Error 'key should be String or Number'
    if @data[key]?
      # console.log "GET: attribute key? #{!@data[key]?}:"+
      "key is #{key}, value is #{@data[key]}"
      return @data[key]
    else
      return @data.attribute[key]

  # delete: (callback) ->
  #   @data.remove (err) ->
  #     callback err


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
        u.__data.attribute = _.clone u.data.attribute
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
        u.data.attribute = {}
        u.isAuthenticate = true
        u.isChanged = true
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
      u.__data = _.clone u.data
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
      @data = _.clone @__data
      return callback.call @, error
    else
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
      delete @
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

class Group extends BBObject
  data: {}
  __data: {}
  constructor: ->

  @create = (attrs, callback) ->
    throw new Error "name is undefined" if !attrs.name
    throw new Error "owner is undefined" if !attrs.owner
    GroupModel.findOne({name: attrs.name}).populate('members', 'username')
    .exec (err, group) ->
      throw err if err
      if group
        error = new Error "group is existed"
        return callback.call group, error, group if group
      group = new Group()
      group.data = new GroupModel()
      group.data.name = attrs.name
      group.data.owners.push attrs.owner.data._id
      group.data.members = []
      group.isChanged = true
      if attrs.members
        for member in attrs.members
          group.data.members.push member._id
      group.save ->
        return callback.call group, null, group

  @find = (attrs, callback) ->
    name = attrs.name
    throw new Error "name is undefined" if !name
    GroupModel.findOne({name: attrs.name}).populate('members', 'username')
    .exec (err, group) ->
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

  addMember: (attrs, callback) ->
    if @ instanceof Group
      @_addMember attrs, (err, group) =>
        @data = group
        @__data = _.clone @data
        callback.call @, err, @
    else
      @_addMember attrs, callback

  _addMember: (attrs, callback) ->
    usernames = attrs.usernames
    groupname = attrs.groupname || @data.name
    if !usernames?
      callback new Error "user names is not undefined", null
    else if !groupname?
      callback new Error "group name is not undefined", null
    else
      GroupModel.findOne({name: groupname}).exec (err, group) =>
        throw err if err
        UserModel.find {username: {$in: usernames}}, (err, users) =>
          throw err if err
          sFunc = []
          sNode = []
          for user in users
            group.members.addToSet user._id
            sNode.push user
            sFunc.push (cb) ->
              u = sNode.shift()
              u.groups.addToSet group._id
              u.save (err) ->
                cb err, u
          group.save (err) =>
            throw err if err
            async.parallel sFunc, (err, results) =>
              throw err if err
              callback.call @, null, group

  removeMember: (attrs, callback) ->
    if @ instanceof Group
      @_removeMember attrs, (err, group) =>
        @data = group
        @__data - _.clone @data
        callback.call @, err, @
    else
      @_removeMember attrs, callback

  _removeMember: (attrs, callback) ->
    if !attrs.usernames?
      callback new Error "user names is not undefined", null
    else if !attrs.groupname?
      callback new Error "group name is not undefined", null
    else
      UserModel.find {username: {$in: attrs.usernames}}, (err, users) =>
        throw err if err
        GroupModel.findOne({name: attrs.groupname}).exec (err, group) =>
          throw err if err
          sFunc = []
          sNode = []
          for user in users
            group.members.pull user._id
            sNode.push user
            sFunc.push (cb) ->
              u = sNode.shift()
              u.groups.pull group._id
              u.save (err) ->
                cb err, u
          group.save (err) =>
            throw err if err
            async.parallel sFunc, (err, results) =>
              throw err if err
              callback.call @, null, group

  addOwner: (attrs, callback) ->
    if !attrs.ownernames?
      callback new Error "owner's name is not undefined", null
    else if !attrs.groupname?
      callback new Error "group's name is not undefined", null
    else
      UserModel.find {username: {$in: attrs.ownernames}}, (err, users) =>
        throw err if err
        GroupModel.findOne {name: attrs.groupname}, (err, group) =>
          throw err if err
          sFunc = []
          sNode = []
          console.log "addowner-users"
          console.log users
          console.log group
          for user in users
            group.owners.addToSet user._id
            sNode.push user
            sFunc.push (cb) ->
              u = sNode.shift()
              u.groups.addToSet group._id
              u.save (err) ->
                cb err, u
          group.save (err) =>
            throw err if err
            async.parallel sFunc, (err, results) =>
              throw err if err
              callback.call @, err, group

  removeOwner: (attrs, callback) ->
    if @ instanceof Group
      @_removeOwner attrs, (err, group) =>
        @data = group
        @__data - _.clone @data
        callback.call @, err, @
    else
      @_removeOwner attrs, callback

  _removeOwner: (attrs, callback) ->
    if !attrs.usernames?
      callback new Error "owner's names is not undefined", null
    else if !attrs.groupname?
      callback new Error "group name is not undefined", null
    else
      UserModel.find {username: {$in: attrs.usernames}}, (err, users) =>
        throw err if err
        GroupModel.findOne({name: attrs.groupname}).exec (err, group) =>
          throw err if err
          sFunc = []
          sNode = []
          for user in users
            group.owners.pull user._id
            sNode.push user
            sFunc.push (cb) ->
              u = sNode.shift()
              u.groups.pull group._id
              u.save (err) ->
                cb err, u
          group.save (err) =>
            throw err if err
            async.parallel sFunc, (err, results) =>
              throw err if err
              callback.call @, null, group

  getMembers: (callback) ->
    q = GroupModel.findOne({name: @data.name})
    q.populate("members", "username device")
    q.exec (err, group) ->
      throw err if err
      callback group.members

ObjectModel = mongoose.model 'object', new mongoose.Schema
  attribute: type: {}

UserModel = mongoose.model "user", new mongoose.Schema
  username: type: String
  password: type: String
  attribute: {}
  device: type: {type: mongoose.Schema.Types.ObjectId, ref: "device"}
  groups: type: [{type: mongoose.Schema.Types.ObjectId, ref: "group"}]

GroupModel = mongoose.model "group", new mongoose.Schema
  name: type: String
  attribute: type: {}
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
