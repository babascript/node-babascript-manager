(function() {
  var redis, _;

  redis = require('redis').createClient();

  _ = require('lodash');

  module.exports = function(app) {
    var Group, Task, User, actors, linda, managerClientAddress, userDataReceiver, userTaskExecute, userTaskFinish, userTaskStart, _ref;
    linda = app.get('linda');
    managerClientAddress = app.get('manager-client-address');
    _ref = app.get('models'), User = _ref.User, Group = _ref.Group, Task = _ref.Task;
    actors = [];
    linda.io.sockets.on("connection", function(socket) {
      var session, user, username, _ref1;
      console.log('connection!!!');
      session = socket.handshake.session;
      user = socket.handshake.user;
      if (((_ref1 = socket.handshake) != null ? _ref1.headers.origin : void 0) === managerClientAddress) {
        console.log("I'm manager client");
      } else if (user.username != null) {
        console.log("I'm actor client");
        username = user.username;
        console.log(username);
        if (_.contains(actors, username)) {
          console.log('already connecting');
          socket.disconnect();
        } else {
          console.log('new connection');
          actors.push(username);
        }
      }
      socket.on("__linda_write", function(data) {
        switch (data.tuple.type) {
          case "update":
            return userDataReceiver(data);
          case "eval":
            return userTaskStart(data);
          case "report":
            return userTaskExecute(data);
          case "return":
            return userTaskFinish(data);
        }
      });
      socket.on("__linda_take", function(data) {});
      return socket.on("disconnect", function(data) {
        var i, name, _i, _len, _ref2, _ref3;
        console.log('disconnect!');
        username = (_ref2 = socket.handshake) != null ? (_ref3 = _ref2.user) != null ? _ref3.username : void 0 : void 0;
        console.log(username);
        if (username) {
          for (i = _i = 0, _len = actors.length; _i < _len; i = ++_i) {
            name = actors[i];
            console.log(name);
            if (name === username) {
              delete actors[i];
            }
          }
          return console.log(actors);
        }
      });
    });
    userDataReceiver = function(data) {
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
    userTaskStart = function(data) {
      var createTask, name;
      console.log('task start');
      console.log(data);
      name = data.tuplespace;
      if (data.tuple.taked === 'virutal') {

      } else {
        createTask = function(data) {
          return Task.findOne({
            cid: data.tuple.cid
          }, function(err, task) {
            if (err) {
              throw err;
            }
            console.log(task);
            if (task == null) {
              task = new Task({
                group: name,
                key: data.tuple.key,
                cid: data.tuple.cid,
                status: 'stock'
              });
              return task.save(function(err) {
                if (err) {
                  throw err;
                }
              });
            }
          });
        };
        return User.findOne({
          username: name
        }).exec(function(err, user) {
          if (err) {
            throw err;
          }
          if (user != null) {
            return createTask(data);
          } else {
            return Group.findOne({
              groupname: name
            }).exec(function(err, group) {
              if (err) {
                throw err;
              }
              if (group == null) {
                return;
              }
              return createTask(data);
            });
          }
        });
      }
    };
    userTaskExecute = function(data) {
      var name, tuple;
      console.log('task execute');
      console.log(data);
      name = data.tuplespace;
      tuple = data.tuple.tuple;
      return User.findOne({
        username: name
      }, function(err, user) {
        if (err) {
          throw err;
        }
        return Task.findOne({
          cid: tuple.cid
        }, function(err, task) {
          if (err) {
            throw err;
          }
          console.log(task);
          if (!task) {
            return;
          }
          task.worker = name;
          task.startAt = Date.now();
          task.status = 'inprocess';
          user.tasks.push(task._id);
          return task.save(function(err) {
            if (err) {
              throw err;
            }
            return user.save(function(err) {
              if (err) {
                throw err;
              }
            });
          });
        });
      });
    };
    return userTaskFinish = function(data) {
      var name;
      console.log('task finish');
      console.log(data);
      name = data.tuplespace;
      return User.findOne({
        username: name
      }, function(err, user) {
        if (err) {
          throw err;
        }
        return Task.findOne({
          cid: data.tuple.cid
        }, function(err, task) {
          if (err) {
            throw err;
          }
          task.value = data.tuple.value;
          task.status = 'finish';
          task.finishAt = Date.now();
          task.text = "" + name + " が、 タスク「" + task.key + "」を終了.";
          return task.save(function(err) {
            if (err) {
              throw err;
            }
          });
        });
      });
    };
  };

}).call(this);
