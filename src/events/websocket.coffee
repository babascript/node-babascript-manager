module.exports = (linda) ->

  linda.io.sockets.on "connect", (socket) ->
    socket.on "__linda_write", (data) ->
      switch data.tuple.type
        when "userdata-write" then userDataReceiver data
        when "eval", "return", "report"
          userTaskReceiver data
    socket.on "__linda_take", (data) ->
      return if data.tuplespace is 'undefined'
      socket.tuplespace = data.tuplespace
      redis.set data.tuplespaec, "on"
      t =
        type: 'userdata'
        key: 'status'
        value: 'on'
        tuplespace: data.tuplespace
      linda.tuplespace(data.tuplespace).write t
    socket.on "disconnect", (data) ->
      name = socket?.tuplespace
      if name
        redis.set name, 'off'
        t =
          type: 'userdata'
          key: 'status'
          value: 'off'
          tuplespace: name
        linda.tuplespace(name).write t

  userDataReceiver = (data) ->

  userTaskReceiver = (data) ->
