(function() {
  var redis;

  redis = require('redis').createClient();

  module.exports = function(app) {
    var Group, Task, User, linda, userDataReceiver, userTaskExecute, userTaskFinish, userTaskStart, _ref;
    linda = app.get('linda');
    _ref = app.get('models'), User = _ref.User, Group = _ref.Group, Task = _ref.Task;
    linda.io.sockets.on("connection", function(socket) {
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
      socket.on("__linda_take", function(data) {
        var t;
        if (data.tuplespace === 'undefined') {
          return;
        }
        socket.tuplespace = data.tuplespace;
        redis.set(data.tuplespace, "agent app");
        t = {
          type: 'userdata',
          key: 'status',
          value: 'agent app',
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
