(function() {
  var LocalStrategy, hat, passport;

  passport = require('passport');

  LocalStrategy = require('passport-local').Strategy;

  hat = require('hat');

  module.exports = function(app) {
    var Token, User;
    User = app.get("models").User;
    Token = app.get("models").Token;
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
    return app.post('/api/session/token', function(req, res, next) {
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
  };

}).call(this);
