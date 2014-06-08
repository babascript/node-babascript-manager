(function() {
  var _;

  _ = require('lodash');

  module.exports = function(app) {
    var User;
    User = app.get("models").User;
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
            password: password
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
        if (err) {
          return res.send(400);
        } else {
          collection = [];
          data = user.attribute;
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
    app.put("/api/user/:name/attributes", function(req, res, next) {
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
              return res.send(200);
            }
          });
        }
      });
    });
    return app.del("/api/user/:name/attribtues", function(req, res, next) {
      var key, username;
      username = req.params.name;
      key = req.body.key;
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err) {
          return res.send(400);
        } else {
          user.attribute[key] = null;
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
  };

}).call(this);
