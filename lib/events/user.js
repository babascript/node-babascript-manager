(function() {
  var hat, _;

  _ = require('lodash');

  hat = require('hat');

  module.exports = function(app) {
    var Device, Notification, Task, TaskLog, User, linda;
    User = app.get("models").User;
    Task = app.get("models").Task;
    Device = app.get("models").Device;
    TaskLog = app.get("models").TaskLog;
    Notification = app.get('helper').Notification;
    linda = app.get("linda");
    app.post("/api/user/new", function(req, res, next) {
      var password, username;
      username = req.body.username;
      password = req.body.password;
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err) {
          throw err;
        }
        if (user != null) {
          return res.send(404);
        } else {
          user = new User({
            username: username,
            password: password,
            token: hat()
          });
          return user.save(function(err) {
            if (err) {
              return res.send(404);
            } else {
              return res.send(201, user);
            }
          });
        }
      });
    });
    app.get("/api/user/:name", function(req, res, next) {
      var username;
      username = req.params.name;
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err || (user == null)) {
          return res.send(404);
        } else {
          return res.send(200, user);
        }
      });
    });
    app.del("/api/user/:name", function(req, res, next) {
      var password, username;
      username = req.params.name;
      password = req.body.password;
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err || (user == null)) {
          return res.send(400);
        } else {
          return user.comparePassword(password, function(err, isMatch) {
            if (err || !isMatch) {
              return res.send(400);
            } else {
              return user.remove(function(err, p) {
                if (err) {
                  return res.send(400);
                } else {
                  return res.send(200);
                }
              });
            }
          });
        }
      });
    });
    app.get("/api/user/:name/attributes", function(req, res, next) {
      var username;
      username = req.params.name;
      return User.findOne({
        username: username
      }, function(err, user) {
        var collection, data;
        if (err || (user == null)) {
          return res.send(400);
        } else {
          collection = [];
          data = user.attribute || {};
          collection.push({
            key: "username",
            value: user.username
          });
          _.each(data, function(v, k) {
            if (v === null) {
              return;
            }
            return collection.push({
              key: k,
              value: v
            });
          });
          return res.send(200, collection);
        }
      });
    });
    app.put("/api/user/:name/attributes/:key", function(req, res, next) {
      var key, username, value, _ref;
      username = req.params.name;
      _ref = req.body, key = _ref.key, value = _ref.value;
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err) {
          return res.send(400);
        } else {
          user.attribute[key] = value;
          user.markModified('attribute');
          return user.save(function(err) {
            if (err) {
              return res.send(400);
            } else {
              res.send(200);
              return linda.tuplespace(user.username).write({
                type: 'userdata',
                username: user.username,
                key: key,
                value: value
              });
            }
          });
        }
      });
    });
    app.del("/api/user/:name/attributes/:key", function(req, res, next) {
      var key, username;
      username = req.params.name;
      key = req.params.key;
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err) {
          return res.send(400);
        } else {
          user.attribute[key] = null;
          user.markModified('attribute');
          return user.save(function(err) {
            if (err) {
              return res.send(400);
            } else {
              return res.send(200);
            }
          });
        }
      });
    });
    app.get('/api/user/:name/tasks', function(req, res, next) {
      var name;
      name = req.params.name;
      return Task.find({
        worker: name
      }).sort('-createdAt').exec(function(err, tasks) {
        if (err) {
          return res.send(400);
        } else {
          return res.send(200, tasks);
        }
      });
    });
    app.get('/api/users', function(req, res, next) {
      var names;
      names = req.body.names;
      if (!_.isArray(names)) {
        names = [names];
      }
      return User.find({
        username: {
          $in: names
        }
      }, function(err, users) {
        if (err || users.length === 0) {
          return res.send(400);
        } else {
          return res.send(200, users);
        }
      });
    });
    app.get('/api/users/all', function(req, res, next) {
      return User.find({}, function(err, users) {
        if (err) {
          return res.send(400);
        } else {
          return res.send(200, users);
        }
      });
    });
    app.put("/api/user/:name/token", function(req, res, next) {
      return User.findOne({
        username: req.params.name
      }, function(err, user) {
        if (err) {
          return res.send(400);
        } else {
          user.token = hat();
          return user.save(function(err) {
            if (err) {
              return res.send(400);
            } else {
              return res.send(200, {
                token: user.token,
                username: user.username
              });
            }
          });
        }
      });
    });
    app.get("/api/user/:name/device", function(req, res, next) {
      return User.findOne({
        username: req.params.name
      }).populate("device").exec(function(err, user) {
        if (err) {
          return res.send(400);
        } else {
          return res.send(200, user);
        }
      });
    });
    app.post("/api/user/:name/device", function(req, res, next) {
      var token, type;
      token = req.body.token;
      type = req.body.type;
      return User.findOne({
        username: req.params.name
      }, function(err, user) {
        var device;
        if (err) {
          return res.send(400);
        } else {
          device = new Device();
          device.token = req.body.token;
          device.type = req.body.type;
          return device.save(function(err) {
            if (err) {
              return res.send(400);
            } else {
              console.log(device);
              user.device = device._id;
              user.devicetoken = token;
              user.devicetype = type;
              return user.save(function(err) {
                if (err) {
                  return res.send(400);
                } else {
                  return res.send(200, device);
                }
              });
            }
          });
        }
      });
    });
    app.get("/api/user/:name/notify", function(req, res, next) {
      return User.findOne({
        username: req.params.name
      }, function(err, user) {
        var token, type;
        if (err) {
          return res.send(400);
        } else {
          token = user.devicetoken;
          type = user.devicetype;
          Notification.sendNotification(type, token, "こんばんわー！！");
          return res.send(200);
        }
      });
    });
    return app.get("/api/user/:name/tasklogs", function(req, res, next) {
      var name;
      name = req.params.name;
      return TaskLog.find().or([
        {
          worker: name
        }, {
          name: name
        }
      ]).sort('-at').exec(function(err, task) {
        console.log(task);
        return res.send(task);
      });
    });
  };

}).call(this);
