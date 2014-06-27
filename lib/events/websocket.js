(function() {
  var redis, _;

  redis = require('redis').createClient();

  _ = require('lodash');

  module.exports = function(app) {
    var Group, Task, User, actors, linda, managerClientAddress, userDataReceiver, _ref;
    linda = app.get('linda');
    managerClientAddress = app.get('manager-client-address');
    _ref = app.get('models'), User = _ref.User, Group = _ref.Group, Task = _ref.Task;
    actors = [];
    linda.io.sockets.on("connection", function(socket) {
      var session, user;
      console.log('connection!!!');
      session = socket.handshake.session;
      user = socket.handshake.user;
      socket.on("__linda_write", function(data) {
        if (data.tuple.type === 'update') {
          return userDataReceiver(data);
        }
      });
      return socket.on("disconnect", function(data) {
        var i, name, username, _i, _len, _ref1, _ref2, _results;
        console.log('disconnect!');
        username = (_ref1 = socket.handshake) != null ? (_ref2 = _ref1.user) != null ? _ref2.username : void 0 : void 0;
        if (username) {
          _results = [];
          for (i = _i = 0, _len = actors.length; _i < _len; i = ++_i) {
            name = actors[i];
            if (name === username) {
              _results.push(actors.splice(i, 1));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        }
      });
    });
    return userDataReceiver = function(data) {
      var key, name, value, _ref1;
      name = data.tuplespace;
      _ref1 = data.tuple, key = _ref1.key, value = _ref1.value;
      return User.findOne({
        username: name
      }, function(err, user) {
        if (err) {
          throw err;
        }
        user.attribute[key] = value;
        user.markModified('attribute');
        return user.save(function(err) {
          var tuple;
          if (err) {
            throw err;
          }
          tuple = {
            type: 'userdata',
            username: name,
            key: key,
            value: value
          };
          return linda.tuplespace(name).write(tuple);
        });
      });
    };
  };

}).call(this);
