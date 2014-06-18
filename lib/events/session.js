(function() {
  var LocalStrategy, hat, passport, _;

  passport = require('passport');

  LocalStrategy = require('passport-local').Strategy;

  hat = require('hat');

  _ = require('lodash');

  module.exports = function(app) {
    var Group, Notification, Token, User;
    User = app.get("models").User;
    Group = app.get("models").Group;
    Token = app.get("models").Token;
    Notification = app.get('helper').Notification;
    passport.serializeUser(function(user, done) {
      console.log('serialize');
      return done(null, user);
    });
    passport.deserializeUser(function(user, done) {
      console.log('deserialize');
      return done(null, user);
    });
    passport.use(new LocalStrategy(function(username, password, done) {
      return User.findOne({
        username: username
      }, function(err, user) {
        if (err) {
          return done(err, false, {
            message: 'An error occurred.'
          });
        }
        if (!user) {
          return done(err, false, {
            message: 'Username not found.'
          });
        }
        return user.comparePassword(password, function(err, isMatch) {
          if (isMatch) {
            return done(err, user);
          } else {
            return done(null, false, {
              message: 'Invalid Password'
            });
          }
        });
      });
    }));
    app.use(passport.initialize());
    app.use(passport.session());
    app.post('/api/session/login', passport.authenticate('local', {
      successRedirect: '/api/session/success',
      failureRedirect: '/api/session/failure'
    }));
    app.post('/api/session/__login', function(req, res, next) {});
    app.get("/api/session", function(req, res, next) {
      var user, _ref, _ref1;
      console.log(req.session);
      if (((_ref = req.session) != null ? (_ref1 = _ref.passport) != null ? _ref1.user : void 0 : void 0) != null) {
        user = req.session.passport.user;
        return res.send(200, {
          username: user.username,
          token: user.token
        });
      } else {
        return res.send(401);
      }
    });
    app.del("/api/session/logout", function(req, res, next) {
      req.logOut();
      return res.send(200);
    });
    app.get('/api/session/success', function(req, res, next) {
      return res.send(200, true);
    });
    app.get('/api/session/failure', function(req, res, next) {
      return res.send(401);
    });
    app.get('/api/session/token', function(req, res, next) {
      return Token.findOne({}, 'token createdAt', {
        sort: {
          createdAt: -1
        }
      }).exec(function(err, token) {
        if (err) {
          return res.send(400, null);
        } else {
          return res.send(200, token);
        }
      });
    });
    app.post('/api/session/token', function(req, res, next) {
      var token;
      token = new Token({
        token: hat()
      });
      return token.save(function(err) {
        if (err) {
          return res.send(400, 'generate token is fail');
        } else {
          return res.send(200, token.token);
        }
      });
    });
    app.get("/api/session/__script", function(req, res, next) {
      var id, ids;
      console.log("/api/session/__script");
      if (_.isArray(req.body.id)) {
        ids = req.body.id;
        console.log("is array");
        console.log(ids);
        return User.find({
          username: {
            $in: ids
          }
        }, function(err, users) {
          if (err) {
            return res.send(400);
          } else {
            return res.send(200, users);
          }
        });
      } else {
        id = req.body.id;
        console.log(id);
        return Group.findOne({
          groupname: id
        }).populate("members", "username attribute").exec(function(err, group) {
          if (err) {
            return res.send(400);
          }
          if (group != null) {
            return res.send(200, group.members);
          } else {
            return User.findOne({
              username: id
            }, function(err, user) {
              var u;
              if (err) {
                return res.send(400);
              }
              if (user == null) {
                return res.send(400);
              } else {
                u = {
                  username: user.username,
                  attribute: user.attribute
                };
                return res.send(200, u);
              }
            });
          }
        });
      }
    });
    return app.post("/api/notification", function(req, res, next) {
      var ids;
      ids = req.body.users;
      if (!_.isArray(ids)) {
        ids = [req.body.users];
      }
      return User.find({
        username: {
          $in: ids
        }
      }, function(err, users) {
        var token, type, user, _i, _len, _results;
        if (err) {
          return res.send(400);
        } else {
          _results = [];
          for (_i = 0, _len = users.length; _i < _len; _i++) {
            user = users[_i];
            token = user.devicetoken;
            type = user.devicetype;
            _results.push(Notification.sendNotification(type, token, "命令が来ます"));
          }
          return _results;
        }
      });
    });
  };

}).call(this);
