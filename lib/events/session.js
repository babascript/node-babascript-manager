(function() {
  var LocalStrategy, passport;

  passport = require('passport');

  LocalStrategy = require('passport-local').Strategy;

  module.exports = function(app) {
    var User;
    User = app.get("models").User;
    passport.serializeUser(function(user, done) {
      return done(null, user._id);
    });
    passport.deserializeUser(function(id, done) {
      return User.findOne({
        _id: id
      }, function(err, user) {
        return done(null, user);
      });
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
    app.get("/api/session", function(req, res, next) {
      var _ref, _ref1;
      console.log(req.session);
      if (((_ref = req.session) != null ? (_ref1 = _ref.passport) != null ? _ref1.user : void 0 : void 0) != null) {
        return res.send(200, true);
      } else {
        return res.send(401);
      }
    });
    app.get("/api/session/logout", function(req, res, next) {
      req.logOut();
      return res.send(200);
    });
    app.get('/api/session/success', function(req, res, next) {
      return res.send(200, true);
    });
    return app.get('/api/session/failure', function(req, res, next) {
      return res.send(401);
    });
  };

}).call(this);
