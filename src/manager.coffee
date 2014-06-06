mongoose = require 'mongoose'
_ = require 'underscore'
Crypto = require 'crypto'
LindaSocketIO = require('linda-socket.io')
LocalStrategy = require('passport-local').Strategy
express = require 'express'
passport = require 'passport'
async = require 'async'
redis = require('redis').createClient()

Linda = LindaSocketIO.Linda
TupleSpace = LindaSocketIO.TupleSpace

class BabascriptManager

  attach: (options = {}) ->
    @io = options.io
    @server = options.server || @io.server
    @app = options.app
    throw new Error 'io not found' if !@io?
    throw new Error 'server not found' if !@server?
    throw new Error 'app not found' if !@app?
    @linda = Linda.listen {io: @io, server: @server}
    @linda.io.sockets.on 'connection', (socket) =>
      socket.on "__linda_write", (data) =>
        if data.tuple.type is 'eval'
          console.log 'task start'
          name = data.tuplespace
          createTask = ->
            task = new TaskModel
              group: name
              key: data.tuple.key
              cid: data.tuple.cid
              status: 'stock'
            task.save (err) ->
              throw err if err
          UserModel.findOne({username: name}).exec (err, user) ->
            throw err if err
            if user?
              createTask()
            else
              GroupModel.findOne({name: name}).exec (err, group) ->
                throw err if err
                return if !group?
                createTask()
        else if data.tuple.type is 'return'
          console.log 'task finish'
          name = data.tuplespace
          @getUser name, (err, user) ->
            TaskModel.findOne {cid: data.tuple.cid}, (err, task) ->
              throw err if err
              # これ、取得したタスクを更新すれば良いだけじゃね
              task.status = 'finish'
              task.finishAt = Date.now()
              task.text = "#{name} が、 タスク「#{task.key}」を終了."
              task.save (err) ->
                throw err if err
        else if data.tuple.type is 'report' and data.tuple.value is 'taked'
          console.log 'task execute'
          name = data.tuplespace
          tuple = data.tuple.tuple
          @getUser name, (err, user) ->
            TaskModel.findOne({cid: tuple.cid}).exec (err, task) ->
              throw err if err
              if !task
                return
              task.worker = name
              task.startAt = Date.now()
              task.status = 'inprocess'
              task.save (err, task) ->
              user.set "tasks", task
              user.isAuthenticate = true
              task.save (err) ->
                throw err if err
                user.save (err) ->
                  throw err if err
      socket.on "__linda_take", (data) ->
        return if data.tuplespace is 'undefined'
        socket.tuplespace = data.tuplespace
        redis.set data.tuplespace, 'on'
    @linda.io.on 'connection', (socket) ->
      socket.on 'disconnect', ->
        name = socket.tuplespace
        if name
          redis.set name, "off"

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
    @app.del '/api/session/logout', (req, res, next) ->
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
      username = req.param 'username'
      password = req.param 'password'
      attrs = {username: username, password: password}
      @createUser attrs, (err, user) ->
        if err or !user?
          res.send 404
        else
          res.send 201, user
    @app.get  '/api/user/:name', (req, res, next) =>
      @getUser req.params.name, (err, user) ->
        if err or !user?
          res.send 404
        else
          {username, device, groups, attribute, tasks} = user.data
          u =
            data:
              username: username
              device: device
              groups: groups
              attribute: attribute
          if req.session.passport.user?.username is user.data?.username
            password = user.data.password
            u.data.password = password
          res.json 200, u

    @app.put  '/api/user/:name', (req, res, next) =>
      # return res.send 404 if !req.session.passport.user?
      username = req.params.name
      password = req.session.passport.user?.password || req.body.password
      data = req.body
      param =
        username: username
        password: password
      @getUser username, (err, user) ->
        if err or !user?
          res.send 500
        # else if req.session.passport.user.username isnt username
        #   res.send 403
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

    @app.get '/api/user/:name/tasks', (req, res, next) ->
      name = req.params.name
      TaskModel.find({worker: name}).sort('-createdAt').exec (err, tasks) ->
        throw err if err
        res.json 200, tasks

    @app.get '/api/user/:name/attributes', (req, res, next) =>
      name = req.params.name
      @getUser name, (err, user) ->
        throw err if err
        collection = []
        o = user.data.toObject()
        collection.push {key: "username", value: user.data.username}
        _.each o.attribute, (v, k) ->
          return if v is null
          collection.push {key: k, value: v}
        _.each o.groups, (v, k) ->
          collection.push {key: "group: #{k}", value: v.name}
        res.send 200, collection

    @app.put '/api/user/:name/attributes/:key', (req, res, next) =>
      name = req.params.name
      {key, value} = req.body
      @getUser name, (err, user) ->
        throw err if err
        user.set key, value
        user.isAuthenticate = true
        user.save (err) ->
          throw err if err
          res.send 200

    @app.del '/api/user/:name/attributes/:key', (req, res, next) =>
      name = req.params.name
      key = req.params.key
      @getUser name, (err, user) ->
        throw err if err
        user.set key, null
        user.isAuthenticate = true
        user.save (err) ->
          throw err if err
          res.send 200

    @app.post '/api/group/new', (req, res, next) =>
      # return res.send 404 if !req.session.passport.user?
      @getUser req.body.owner, (err, user) =>
        attrs =
          owner: user
          name: req.body.name
        @createGroup attrs, (err, group) ->
          if !err
            res.send 404, err
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

    @app.get '/api/group/:name/member', (req, res, next) =>
      attr =
        name: req.params.name
      @getGroup attr, (err, group) ->
        return res.send 404, err if err or !group?
        data = []
        _.each group.data.members, (member) ->
          console.log member
          data.push
            username: member.username
            attribute: member.attribute
        res.send 200, data

    @app.post '/api/group/:name/member', (req, res, next) =>
      # return res.send 404, "not logined" if !req.session.passport.user?
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
          ownernames: req.body.ownernames
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
          ownernames: req.body.ownernames
        group.removeOwner data, (err, g) ->
          return res.send 404, err if err or !g?
          return res.send 200, g

    @app.get '/api/group/:name/tasks', (req, res, next) =>
      attr =
        name: req.params.name
      @getGroup attr, (err, group) ->
        members = _.pluck group.data.members, "username"
        members = if _.isArray members then members else [members]
        members.push attr.name
        TaskModel.find({worker: {$in: members}}).sort('-createdAt')
        .exec (err, tasks) ->
          throw err if err
          res.send 200, tasks

    # webhook API

    @app.get "/api/webhook/:cid", (req, res, next) =>
      tuple = req.body.tuple
      options = req.body.options
      name = req.body.tuplespace
      @linda.tuplespace(name).write tuple, options
      @linda.emit "write", tuple
      res.send 200, tuple

    @app.post "/api/webhook/:cid", (req, res, next) =>
      tuple = req.body.tuple
      options = req.body.options
      name = req.body.tuplespace
      @linda.tuplespace(name).write tuple, options
      @linda.emit "write", {tuple: tuple, options: options}
      res.send 200

    # I'm baba

    @app.get "/api/imbaba/:name", (req, res, next) =>
      name = req.params.name
      @getGroup {name: name}, (err, group) =>
        throw err if err
        if group
          json =
            group: group
          return res.json 200, {group: group}
        else
          @getUser name, (err, user) ->
            throw err if err
            if user
              return res.json 200, {user: user}
            else
              return res.send 404

    @app.get "/api/isconnecting/:tuplespace", (req, res, next) ->
      name = req.params.tuplespace
      redis.get name, (err, reply) ->
        throw err if err
        if reply is "on"
          res.send 200, true
        else
          res.send 200, false

    # Basic View Rendering
    @app.get "/views/user/:name", (req, res, next) ->
    @app.get "/views/group/:name", (req, res, next) ->
    @app.get "/", (req, res, next) ->
    return @

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
    # return callback false, null if !owner? or !owner.isAuthenticate
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
      if _.isArray @data.attribute[key]
        @data.attribute[key].push value
      else
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
    UserModel.findOne({username: username}).populate('groups', 'name')
    .exec (err, user) ->
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
    GroupModel.findOne({name: name}).populate('members', 'username attribute')
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
        if !_.isArray(usernames)
          usernames = [usernames]
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
      usernames = attrs.usernames
      if !_.isArray(usernames)
        usernames = [usernames]
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
      ownernames = attrs.ownernames
      if !_.isArray(ownernames)
        ownernames = [ownernames]
      UserModel.find {username: {$in: attrs.ownernames}}, (err, users) =>
        throw err if err
        GroupModel.findOne {name: attrs.groupname}, (err, group) =>
          throw err if err
          sFunc = []
          sNode = []
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
    console.log attrs
    if !attrs.ownernames?
      callback new Error "owner's names is not undefined", null
    else if !attrs.groupname?
      callback new Error "group name is not undefined", null
    else
      ownernames = attrs.ownernames
      if !_.isArray(ownernames)
        ownernames = [ownernames]
      UserModel.find {username: {$in: ownernames}}, (err, users) =>
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
  createdAt: type: Date
  updatedAt: type: Date
  tasks: type: [{type: mongoose.Schema.Types.ObjectId, ref: "task"}]
  device: type: {type: mongoose.Schema.Types.ObjectId, ref: "device"}
  groups: type: [{type: mongoose.Schema.Types.ObjectId, ref: "group"}]

GroupModel = mongoose.model "group", new mongoose.Schema
  name: type: String
  attribute: type: {}
  owners: type: [{type: mongoose.Schema.Types.ObjectId, ref: "user"}]
  members: type: [{type: mongoose.Schema.Types.ObjectId, ref: "user"}]

TaskModel = mongoose.model "task", new mongoose.Schema
  text: type: String
  status: type: String
  worker: type: String
  cid: type: String
  key: type: String
  group: type: String
  startAt: {type: Date, default: ""}
  finishAt: {type: Date, default: ""}
  createdAt: {type: Date, default: Date.now}


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
