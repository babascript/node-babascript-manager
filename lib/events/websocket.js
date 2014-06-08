(function() {
  module.exports = function(linda) {
    var userDataReceiver, userTaskReceiver;
    linda.io.sockets.on("connect", function(socket) {
      socket.on("__linda_write", function(data) {
        switch (data.tuple.type) {
          case "userdata-write":
            return userDataReceiver(data);
          case "eval":
          case "return":
          case "report":
            return userTaskReceiver(data);
        }
      });
      socket.on("__linda_take", function(data) {
        var t;
        if (data.tuplespace === 'undefined') {
          return;
        }
        socket.tuplespace = data.tuplespace;
        redis.set(data.tuplespaec, "on");
        t = {
          type: 'userdata',
          key: 'status',
          value: 'on',
          tuplespace: data.tuplespace
        };
        return linda.tuplespace(data.tuplespace).write(t);
      });
      return socket.on("disconnect", function(data) {
        var name, t;
        name = socket != null ? socket.tuplespace : void 0;
        if (name) {
          redis.set(name, 'off');
          t = {
            type: 'userdata',
            key: 'status',
            value: 'off',
            tuplespace: name
          };
          return linda.tuplespace(name).write(t);
        }
      });
    });
    userDataReceiver = function(data) {};
    return userTaskReceiver = function(data) {};
  };

}).call(this);
