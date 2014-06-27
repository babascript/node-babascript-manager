(function() {
  var BabascriptManager, Linda, LindaSocketIO, LocalStrategy, TupleSpace, cookie, direquire, express, mongoose, passport, path, pkg, session;

  mongoose = require('mongoose');

  LindaSocketIO = require('linda-socket.io');

  LocalStrategy = require('passport-local').Strategy;

  express = require('express');

  cookie = require('cookie');

  session = require('express-session');

  passport = require('passport');

  direquire = require('direquire');

  path = require('path');

  pkg = require(path.resolve('package.json'));

  Linda = LindaSocketIO.Linda, TupleSpace = LindaSocketIO.TupleSpace;

  BabascriptManager = (function() {
    function BabascriptManager() {
      console.log('init!');
    }

    BabascriptManager.prototype.attach = function(options) {
      var Events, Helper, Models, RedisStore;
      if (options == null) {
        options = {};
      }
      this.io = options.io;
      this.server = options.server || this.io.server;
      this.app = options.app;
      if (this.io == null) {
        throw new Error('io not found');
      }
      if (this.server == null) {
        throw new Error('server not found');
      }
      if (this.app == null) {
        throw new Error('app not found');
      }
      this.linda = Linda.listen({
        io: this.io,
        server: this.server
      });
      this.app.use(function(req, res, next) {
        var headers, methods;
        headers = 'Content-Type, Authorization, Content-Length,';
        headers += 'X-Requested-With, Origin, Accept-Encoding';
        methods = 'POST, PUT, GET, DELETE, OPTIONS';
        console.log(req.headers.origin);
        res.setHeader('Access-Control-Allow-Origin', req.headers.origin);
        res.setHeader('Access-Control-Allow-Credentials', true);
        res.setHeader('Access-Control-Allow-Methods', methods);
        res.setHeader('Access-Control-Allow-Headers', "*");
        res.setHeader('Access-Control-Allow-Accept-Encoding', "gzip");
        res.setHeader('Access-Control-Request-Method', methods);
        res.setHeader('Access-Control-Allow-Headers', headers);
        return next();
      });
      RedisStore = (require('connect-redis'))(session);
      this.app.use(session({
        store: new RedisStore({
          prefix: "sess:" + pkg.name + ":"
        }),
        secret: 'keyboard cat',
        cookie: {
          expires: false
        }
      }));
      Events = {
        Group: require("./events/group"),
        Session: require("./events/session"),
        User: require("./events/user"),
        Websocket: require("./events/websocket")
      };
      Models = require("./models/model");
      Helper = {
        Notification: require("./helper/notification")
      };
      this.app.set('events', Events);
      this.app.set('models', Models);
      this.app.set('helper', Helper);
      this.app.set('linda', this.linda);
      Events.Session(this.app);
      Events.User(this.app);
      Events.Group(this.app);
      Events.Websocket(this.app);
      if (options.secure != null) {
        return this.io.configure((function(_this) {
          return function() {
            return _this.io.set("authorization", function(handshakeData, callback) {
              var token, _ref;
              console.log('authorization');
              console.log(handshakeData);
              token = (_ref = handshakeData.query) != null ? _ref.token : void 0;
              if (handshakeData.headers['user-agent'] === 'node-XMLHttpRequest') {
                return callback(null, true);
              }
              if (token == null) {
                return callback('error', false);
              } else {
                return Models.User.findOne({
                  token: token
                }, function(err, user) {
                  if (err) {
                    throw err;
                  }
                  handshakeData.user = user;
                  if (user) {
                    return callback(null, true);
                  } else {
                    return callback('token not found', false);
                  }
                });
              }
            });
          };
        })(this));
      }
    };

    return BabascriptManager;

  })();

  module.exports = new BabascriptManager();

}).call(this);
