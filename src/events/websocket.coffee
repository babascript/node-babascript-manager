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
    if socket.handshake?.headers.origin is managerClientAddress
      console.log "I'm manager client"
      # Actorとかには追加しない
    else if session?.passport?.user.username
      console.log "I'm actor client"
      username = session.passport.user.username
      console.log username
      if _.contains actors, username
        console.log 'already connecting'
        socket.disconnect()
      else
        console.log 'new connection'
        actors.push username
      # 既にクライアントとして接続中であれば接続を許可しない
      # 既にプログラムで実行中であれば、接続を拒否する、とか。
    socket.on "__linda_write", (data) ->
      switch data.tuple.type
        when "update" then userDataReceiver data
        when "eval" then userTaskStart data
        when "report" then userTaskExecute data
        when "return" then userTaskFinish data
    socket.on "__linda_take", (data) ->
      # return if data.tuplespace is 'undefined'
      # socket.tuplespace = data.tuplespace
      # redis.set data.tuplespace, "agent app"
      # t =
      #   type: 'userdata'
      #   key: 'status'
      #   value: 'agent app'
      #   tuplespace: data.tuplespace
      # linda.tuplespace(data.tuplespace).write t
    socket.on "disconnect", (data) ->
      # Actors から削除する仕組み
      console.log 'disconnect!'
      username = socket.handshake?.session?.passport?.user.username
      console.log username
      if username
        for name, i in actors
          console.log name
          delete actors[i] if name is username
        console.log actors
      # name = socket?.tuplespace
      # if name
      #   redis.set name, 'off'
      #   t =
      #     type: 'userdata'
      #     key: 'status'
      #     value: 'off'
      #     tuplespace: name
      #   linda.tuplespace(name).write t

  userDataReceiver = (data) ->
    # console.log 'data receive'
    # console.log data
    name = data.tuplespace
    # console.log name
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
  userTaskStart = (data) ->
    # virtual client のせいで、evalが2回起きてる？
    console.log 'task start'
    console.log data
    name = data.tuplespace
    if data.tuple.taked is 'virutal'
      return
    else
      createTask = (data) ->
        Task.findOne {cid: data.tuple.cid}, (err, task) ->
          throw err if err
          console.log task
          if !task?
            task = new Task
              group: name
              key: data.tuple.key
              cid: data.tuple.cid
              status: 'stock'
            task.save (err) ->
              throw err if err
      User.findOne({username: name}).exec (err, user) ->
        throw err if err
        if user?
          createTask(data)
        else
          Group.findOne({groupname: name}).exec (err, group) ->
            throw err if err
            return if !group?
            createTask(data)
  userTaskExecute = (data) ->
    console.log 'task execute'
    console.log data
    # console.log data.tuple.tuple
    name = data.tuplespace
    tuple = data.tuple.tuple
    User.findOne {username: name}, (err, user) ->
      throw err if err
      Task.findOne {cid: tuple.cid}, (err, task) ->
        throw err if err
        console.log task
        if !task
          return
        task.worker = name
        task.startAt = Date.now()
        task.status = 'inprocess'
        user.tasks.push task._id
        task.save (err) ->
          throw err if err
          user.save (err) ->
            throw err if err
  userTaskFinish = (data) ->
    console.log 'task finish'
    console.log data
    name = data.tuplespace
    User.findOne {username: name}, (err, user) ->
      throw err if err
      Task.findOne {cid: data.tuple.cid}, (err, task) ->
        throw err if err
        task.status = 'finish'
        task.finishAt = Date.now()
        task.text = "#{name} が、 タスク「#{task.key}」を終了."
        task.save (  err) ->
          throw err if err
