redis = require('redis').createClient()
_ = require 'lodash'

module.exports = (app) ->
  linda = app.get 'linda'
  managerClientAddress = app.get 'manager-client-address'
  {User, Group, Task} = app.get 'models'
  actors = []
  linda.io.sockets.on "connection", (socket) ->
    console.log 'connection!!!'
    session = socket.handshake.session
    user = socket.handshake.user
    # ユーザ認証、どうする？
    socket.on "__linda_write", (data) ->
      userDataReceiver(data) if data.tuple.type is 'update'
    socket.on "disconnect", (data) ->
      # Actors から削除する仕組み
      console.log 'disconnect!'
      # username = socket.handshake?.session?.passport?.user.username
      username = socket.handshake?.user?.username
      if username
        for name, i in actors
          actors.splice i, 1 if name is username

  userDataReceiver = (data) ->
    name = data.tuplespace
    {key, value} = data.tuple
    User.findOne {username: name}, (err, user) ->
      throw err if err
      user.attribute[key] = value
      user.markModified 'attribute'
      user.save (err) ->
        throw err if err
        tuple =
          type: 'userdata'
          username: name
          key: key
          value: value
        linda.tuplespace(name).write tuple
