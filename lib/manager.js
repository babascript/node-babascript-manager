(function() {
  var BBObject, BabascriptManager, CONNECT, Crypto, DeviceModel, Group, GroupModel, Linda, LindaSocketIO, LocalStrategy, ObjectModel, TupleSpace, User, UserModel, async, express, mongoose, passport, _,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  mongoose = require('mongoose');

  CONNECT = 1;

  console.log(mongoose.connection.readyState);

  _ = require('underscore');

  Crypto = require('crypto');

  LindaSocketIO = require('linda-socket.io');

  LocalStrategy = require('passport-local').Strategy;

  express = require('express');

  passport = require('passport');

  async = require('async');

  Linda = LindaSocketIO.Linda;

  TupleSpace = LindaSocketIO.TupleSpace;

  console.log(mongoose);

  BabascriptManager = (function() {
    function BabascriptManager() {}

    BabascriptManager.prototype.attach = function(io, app) {
      var auth;
      this.io = io;
      this.app = app;
      if (this.io == null) {
        throw new Error('io not found');
      }
      if (this.io.server == null) {
        throw new Error('server not found');
      }
      if (this.app == null) {
        throw new Error('app not found');
      }
      this.linda = Linda.listen({
        io: this.io,
        server: this.io.server
      });
      this.linda.io.set('log lebel', 2);
      this.linda.io.on('connection', function(socket) {
        socket.on('disconnect', function() {});
        socket.on('__linda_write', function(data) {});
        socket.on('__linda_take', function(data) {});
        return socket.on('__linda_cancel', function(data) {});
      });
      passport.serializeUser(function(data, done) {
        var password, u, username;
        username = data.username;
        password = data.password;
        u = {
          username: username,
          password: password
        };
        return done(null, u);
      });
      passport.deserializeUser(function(data, done) {
        return done(null, data);
      });
      passport.use(new LocalStrategy((function(_this) {
        return function(username, password, done) {
          var data;
          data = {
            username: username,
            password: password
          };
          return _this.login(data, function(err, user) {
            if (err) {
              return done(err, null);
            } else if (!user) {
              return done(null, null, {
                message: 'invalid user'
              });
            } else {
              return done(null, data);
            }
          });
        };
      })(this)));
      this.app.use(passport.initialize());
      this.app.use(passport.session());
      auth = passport.authenticate('local', {
        successRedirect: '/',
        failureRedirect: '/api/session/failure',
        failureFlash: false
      });
      this.app.get('/api/imbaba/:name', (function(_this) {
        return function(req, res, next) {
          var attr;
          attr = {
            name: req.params.name
          };
          return _this.getGroup(attr, function(err, group) {
            var members;
            if (err || (group == null)) {
              return res.send(400);
            } else {
              members = group.get("members");
              return res.send(200, members);
            }
          });
        };
      })(this));
      this.app.post('/api/session/login', function(req, res, next) {
        return auth(req, res, next);
      });
      this.app["delete"]('/api/session/logout', function(req, res, next) {
        delete req.session;
        return res.send(200);
      });
      this.app.get('/api/session', function(req, res, next) {
        if (req.session.passport.user != null) {
          return res.send(200);
        } else {
          return res.send(404);
        }
      });
      this.app.get('/api/session/success', function(req, res, next) {
        return res.send(200);
      });
      this.app.get('/api/session/failure', function(req, res, next) {
        return res.send(500);
      });
      this.app.post('/api/user/new', (function(_this) {
        return function(req, res, next) {
          var attrs, password, username;
          if (req.session.passport.user == null) {
            return res.send(404);
          }
          username = req.param('username');
          password = req.param('password');
          attrs = {
            username: username,
            password: password
          };
          return _this.createUser(attrs, function(err, user) {
            if (err || (user == null)) {
              return res.send(404);
            } else {
              return res.send(200, user);
            }
          });
        };
      })(this));
      this.app.get('/api/user/:name', (function(_this) {
        return function(req, res, next) {
          return _this.getUser(req.params.name, function(err, user) {
            var u, _ref, _ref1;
            if (err || (user == null)) {
              return res.send(404);
            } else {
              if (((_ref = req.session.passport.user) != null ? _ref.username : void 0) === ((_ref1 = user.data) != null ? _ref1.username : void 0)) {
                return res.json(200, user);
              } else {
                u = {
                  data: {
                    username: user.data.username
                  }
                };
                return res.json(200, u);
              }
            }
          });
        };
      })(this));
      this.app.put('/api/user/:name', (function(_this) {
        return function(req, res, next) {
          var data, param, password, username, _ref;
          if (req.session.passport.user == null) {
            return res.send(404);
          }
          username = req.params.name;
          password = (_ref = req.session.passport.user) != null ? _ref.password : void 0;
          data = req.body;
          param = {
            username: username,
            password: password
          };
          return _this.getUser(username, function(err, user) {
            if (err || (user == null)) {
              return res.send(500);
            } else if (req.session.passport.user.username !== username) {
              return res.send(403);
            } else {
              return user.authenticate(password, function(result) {
                var key, value;
                if (!result) {
                  return res.send(404);
                } else {
                  for (key in data) {
                    value = data[key];
                    if (key === 'password') {
                      value = Crypto.createHash("sha256").update(value).digest("hex");
                    }
                    user.set(key, value);
                  }
                  return user.save(function(err) {
                    if (err) {
                      throw err;
                    }
                    return res.send(200);
                  });
                }
              });
            }
          });
        };
      })(this));
      this.app.del('/api/user/:name', (function(_this) {
        return function(req, res, next) {
          var password, username;
          if (req.session.passport.user == null) {
            return res.send(404);
          }
          username = req.params.name;
          password = req.body.password;
          return _this.getUser(username, function(err, user) {
            if (err || (user == null)) {
              return res.send(500);
            } else if (req.session.passport.user.username !== username) {
              return res.send(403);
            } else {
              return user.authenticate(password, function(result) {
                if (!result) {
                  return res.send(403);
                } else {
                  return user["delete"](function(err) {
                    if (err) {
                      throw err;
                    }
                    return res.send(200);
                  });
                }
              });
            }
          });
        };
      })(this));
      this.app.post('/api/group/new', function(req, res, next) {
        var attrs;
        if (req.session.passport.user == null) {
          return res.send(404);
        }
        attrs = {
          owner: req.body.owner,
          name: req.body.name
        };
        return this.createGroup(attrs, function(err, group) {
          if (err || (group == null)) {
            return res.send(404);
          } else {
            return res.send(200, group);
          }
        });
      });
      this.app.get('/api/group/:name', (function(_this) {
        return function(req, res, next) {
          var attr;
          attr = {
            name: req.params.name
          };
          return _this.getGroup(attr, function(err, group) {
            if (err || (group == null)) {
              return res.send(404, err);
            } else {
              return res.send(200, group);
            }
          });
        };
      })(this));
      this.app.put('/api/group/:name', (function(_this) {
        return function(req, res, next) {
          var attr, data;
          if (req.session.passport.user == null) {
            return res.send(404);
          }
          attr = {
            name: req.params.name
          };
          data = req.body;
          return _this.getGroup(attr, function(err, group) {
            var key, value;
            if (err || (group == null)) {
              return res.send(404, err);
            } else {
              for (key in data) {
                value = data[key];
                group.set(key, value);
              }
              return group.save(function(err) {
                if (err) {
                  return res.send(404, err);
                }
                return res.send(200);
              });
            }
          });
        };
      })(this));
      this.app.del('/api/group/:name', function(req, res, next) {
        if (req.session.passport.user == null) {
          return res.send(404);
        }
        return res.send(200);
      });
      this.app.post('/api/group/:name/member', (function(_this) {
        return function(req, res, next) {
          var attr, data;
          if (req.session.passport.user == null) {
            return res.send(404, "not logined");
          }
          attr = {
            name: req.params.name
          };
          data = req.body;
          return _this.getGroup(attr, function(err, group) {
            if (err || (group == null)) {
              return res.send(404, err);
            }
            data = {
              groupname: req.params.name,
              usernames: req.body.names
            };
            return group.addMember(data, function(err, g) {
              if (err || (g == null)) {
                return res.send(404, err);
              }
              return res.send(200, g);
            });
          });
        };
      })(this));
      this.app.del('/api/group/:name/member', (function(_this) {
        return function(req, res, next) {
          var attr, data;
          if (req.session.passport.user == null) {
            return res.send(404, "not logined");
          }
          attr = {
            name: req.params.name
          };
          data = req.body;
          return _this.getGroup(attr, function(err, group) {
            if (err || (group == null)) {
              return res.send(404, err);
            }
            data = {
              groupname: req.params.name,
              usernames: req.body.names
            };
            return group._removeMember(data, function(err, g) {
              if (err || (g == null)) {
                return res.send(404, err);
              }
              return res.send(200, g);
            });
          });
        };
      })(this));
      this.app.get('/api/group/:name/owner', function(req, res, next) {});
      this.app.post('/api/group/:name/owner', (function(_this) {
        return function(req, res, next) {
          var attr;
          if (req.session.passport.user == null) {
            return res.send(404, "not logined");
          }
          attr = {
            name: req.params.name
          };
          return _this.getGroup(attr, function(err, group) {
            var data;
            if (err || (group == null)) {
              return res.send(404, err);
            }
            data = {
              groupname: req.params.name,
              ownernames: req.body.names
            };
            return group.addOwner(data, function(err, g) {
              if (err || (g == null)) {
                return res.send(404, err);
              }
              return res.send(200, g);
            });
          });
        };
      })(this));
      this.app.put('/api/group/:name/owner', function(req, res, next) {});
      this.app.del('/api/group/:name/owner', (function(_this) {
        return function(req, res, next) {
          var attr;
          if (req.session.passport.user == null) {
            return res.send(404, "not logined");
          }
          attr = {
            name: req.params.name
          };
          return _this.getGroup(attr, function(err, group) {
            var data;
            if (err || (group == null)) {
              return res.send(404, err);
            }
            data = {
              groupname: req.params.name,
              usernames: req.body.names
            };
            return group.removeOwner(data, function(err, g) {
              if (err || (g == null)) {
                return res.send(404, err);
              }
              return res.send(200, g);
            });
          });
        };
      })(this));
      this.app.get("/api/webhook/:cid", (function(_this) {
        return function(req, res, next) {
          var name, options, tuple;
          tuple = req.body.tuple;
          options = req.body.options;
          name = req.body.tuplespace;
          _this.linda.tuplespace(name).write(tuple, options);
          console.log(_this.linda.tuplespace("baba"));
          _this.linda.emit("write", tuple);
          return res.send(200, tuple);
        };
      })(this));
      this.app.post("/api/webhook/:cid", (function(_this) {
        return function(req, res, next) {
          var name, options, tuple;
          tuple = req.body.tuple;
          options = req.body.options;
          name = req.body.tuplespace;
          _this.linda.tuplespace(name).write(tuple, options);
          _this.linda.emit("write", {
            tuple: tuple,
            options: options
          });
          return res.send(200);
        };
      })(this));
      this.app.get("/api/imbaba/:name", (function(_this) {
        return function(req, res, next) {
          var name;
          name = req.params.name;
          return _this.getGroup({
            name: name
          }, function(err, group) {
            var json;
            if (err) {
              throw err;
            }
            if (group) {
              json = {
                group: group
              };
              return res.json(200, {
                group: group
              });
            } else {
              return _this.getUser(name, function(err, user) {
                if (err) {
                  throw err;
                }
                if (user) {
                  return res.json(200, {
                    user: user
                  });
                } else {
                  return res.send(404);
                }
              });
            }
          });
        };
      })(this));
      return this;
    };

    BabascriptManager.prototype.createUser = function(attrs, callback) {
      var password, username;
      username = attrs.username;
      password = attrs.password;
      return User.create(username, password, function(err, user) {
        var error;
        if (err) {
          return callback(err, null);
        }
        if (user == null) {
          error = new Error('user not found');
          return callback(error, user);
        } else {
          return callback(null, user);
        }
      });
    };

    BabascriptManager.prototype.getUser = function(username, callback) {
      return User.find(username, callback);
    };

    BabascriptManager.prototype.createGroup = function(attrs, callback) {
      var owner;
      owner = attrs.owner;
      if ((owner == null) || !owner.isAuthenticate) {
        return callback(false, null);
      }
      return Group.create(attrs, function(status, group) {
        if (group == null) {
          return callback(false, null);
        } else {
          return callback(true, group);
        }
      });
    };

    BabascriptManager.prototype.getGroup = function(attrs, callback) {
      return Group.find(attrs, callback);
    };

    BabascriptManager.prototype.login = function(attrs, callback) {
      return User.login(attrs, function(err, user) {
        return callback(err, user);
      });
    };

    return BabascriptManager;

  })();

  BBObject = (function() {
    BBObject.prototype.data = {};

    BBObject.prototype.__data = {};

    function BBObject(attr) {
      this._serverData = {};
      this.isChanged = false;
    }

    BBObject.prototype.save = function(callback) {
      var error;
      if (!this.isChanged) {
        return callback.call(this, new Error("not change"));
      }
      if ((this.data == null) || (this.__data == null)) {
        error = new Error('data is undefined');
        return callback.call(this, error);
      } else {
        return this.data.save((function(_this) {
          return function(err) {
            if (err) {
              _this.data = _.clone(_this.__data);
            } else {
              _this.__data = _.clone(_this.data);
            }
            callback.call(_this, err);
            return _this.isChanged = false;
          };
        })(this));
      }
    };

    BBObject.prototype.set = function(key, value) {
      if (!(typeof key === 'string') && !(typeof key === 'number')) {
        throw new Error('key should be String or Number');
      }
      this.isChanged = true;
      if (this.data[key] != null) {
        return this.data[key] = value;
      } else {
        if (this.data.attribute == null) {
          this.data.attribute = {};
        }
        this.data.attribute[key] = value;
        return this.data.markModified('attribute');
      }
    };

    BBObject.prototype.get = function(key) {
      if ((typeof key !== 'string') && (typeof key !== 'number')) {
        throw new Error('key should be String or Number');
      }
      if (this.data[key] != null) {
        "key is " + key + ", value is " + this.data[key];
        return this.data[key];
      } else {
        return this.data.attribute[key];
      }
    };

    return BBObject;

  })();

  User = (function(_super) {
    __extends(User, _super);

    function User() {
      return User.__super__.constructor.apply(this, arguments);
    }

    User.prototype.isAuthenticate = false;

    User.prototype.username = '';

    User.prototype.password = '';

    User.prototype.groups = [];

    User.prototype.devices = [];

    User.find = function(username, callback) {
      var u;
      if (!username) {
        throw new Error("username is undefined");
      }
      u = new User();
      return UserModel.findOne({
        username: username
      }, function(err, user) {
        var error;
        if (err) {
          throw err;
        }
        if (!user) {
          error = new Error("user not found");
          return callback(error, null);
        } else {
          u.data = user;
          u.__data = _.clone(u.data);
          u.__data.attribute = _.clone(u.data.attribute);
          u.isAuthenticate = false;
          return callback.call(u, null, u);
        }
      });
    };

    User.authenticate = function(username, password, callback) {
      if (!username) {
        throw new Error("username is undefined");
      }
      if (!password) {
        throw new Error("password is undefined");
      }
      return UserModel.findOne({
        username: username,
        password: password
      }, function(err, user) {
        var u;
        if (err) {
          throw err;
        }
        if (!user) {
          return callback(null);
        }
        u = new User();
        u.isAuthenticate = true;
        u.data = user;
        u.__data = _.clone(u.data);
        return callback(u);
      });
    };

    User.create = function(username, password, callback) {
      if (!username) {
        throw new Error("username is undefined");
      }
      if (!password) {
        throw new Error("password is undefined");
      }
      return UserModel.findOne({
        username: username
      }, function(err, user) {
        var error, pass, u;
        if (err) {
          throw err;
        }
        if (user) {
          error = new Error("already user exist");
          return callback.call(user, error, user);
        } else {
          u = new User();
          pass = Crypto.createHash("sha256").update(password).digest("hex");
          u.data = new UserModel();
          u.data.username = username;
          u.data.password = pass;
          u.data.attribute = {};
          u.isAuthenticate = true;
          u.isChanged = true;
          return u.save(function(err) {
            return callback.call(u, err, u);
          });
        }
      });
    };

    User.login = function(attrs, callback) {
      var pass, password, username;
      username = attrs.username;
      password = attrs.password;
      if (!username) {
        throw new Error("username is undefined");
      }
      if (!password) {
        throw new Error("password is undefined");
      }
      pass = Crypto.createHash("sha256").update(password).digest("hex");
      return UserModel.findOne({
        username: username,
        password: pass
      }, function(err, user) {
        var u;
        if (err) {
          throw err;
        }
        if (user == null) {
          return callback(new Error("authenticate failed"), null);
        }
        u = new User();
        u.data = user;
        u.__data = _.clone(u.data);
        u.isAuthenticate = true;
        return callback(null, u);
      });
    };

    User.prototype.authenticate = function(password, callback) {
      var p, username;
      username = this.get("username");
      if (username == null) {
        throw new Error("username is undefined");
      }
      if (password == null) {
        throw new Error("password is undefined");
      }
      p = Crypto.createHash("sha256").update(password).digest("hex");
      return UserModel.findOne({
        username: username,
        password: p
      }, (function(_this) {
        return function(err, user) {
          if (err) {
            throw err;
          }
          if (user == null) {
            return callback(false);
          }
          _this.isAuthenticate = true;
          return callback.call(_this, _this.isAuthenticate);
        };
      })(this));
    };

    User.prototype.save = function(callback) {
      var error;
      if (!this.isAuthenticate) {
        error = new Error("ERROR: user isn't authenticated");
        this.data = _.clone(this.__data);
        return callback.call(this, error);
      } else {
        return User.__super__.save.call(this, callback);
      }
    };

    User.prototype["delete"] = function(callback) {
      if (!this.isAuthenticate) {
        return callback(new Error("not authenticated"), false);
      }
      return this.data.remove(function(err, user) {
        if (err) {
          throw err;
        }
        delete this;
        return callback(null, true);
      });
    };

    User.prototype.addGroup = function(name, callback) {
      if (!this.data) {
        return callback(false);
      }
      return GroupModel.findOne({
        name: name
      }, (function(_this) {
        return function(err, group) {
          var g;
          if (err) {
            throw err;
          }
          if (!group) {
            return callback(false);
          }
          g = _.find(_this.data.groups, function(group) {
            return group.name === name;
          });
          if (!g) {
            _this.data.groups.push(group._id);
          }
          return _this.data.save(function(err) {
            var member;
            if (err) {
              throw err;
            }
            member = _.find(group.members, function(m) {
              return m._id === this.data._id;
            });
            if (!member) {
              group.members.push(this.data._Id);
            }
            return group.save(function(err) {
              if (err) {
                throw err;
              }
              return callback(this.data);
            });
          });
        };
      })(this));
    };

    User.prototype.removeGroup = function(name, callback) {
      if (!this.data || !this.username) {
        return callback(false);
      }
      return GroupModel.findOne({
        name: name
      }, function(err, group) {
        if (err) {
          throw err;
        }
        return UserModel.findOne({
          username: this.username
        }, function(err, user) {
          var i, _i, _ref;
          if (err) {
            throw err;
          }
          for (i = _i = 0, _ref = user.groups.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
            if (user.groups[i].name === name) {
              user.groups.split(i, 1);
            }
          }
          return user.save(function(err) {
            if (err) {
              throw err;
            }
            return callback(true);
          });
        });
      });
    };

    User.prototype.getDevice = function(uuid, callback) {
      if (this.data) {
        return callback(this.data, this.data.device);
      } else {
        return this.find({
          username: this.username
        }, function(err, user) {
          if (err) {
            throw err;
          }
          return callback(user, user.device);
        });
      }
    };

    User.prototype.addDevice = function(device, callback) {
      return this.getDevice(device.uuid, function(user, device) {
        if (device) {
          return true;
        }
        device = new DeviceModel();
        device.uuid = device.uuid;
        device.type = device.type;
        device.token = device.token;
        device.endpoint = device.endpoint;
        device.owner = user._id;
        return device.save(function(err) {
          if (err) {
            throw err;
          }
          user.device = device;
          return user.save(function(err) {
            if (err) {
              throw err;
            }
            return callback(device);
          });
        });
      });
    };

    User.prototype.removeDevice = function(uuid, callback) {
      return this.getDevice(uuid, function(user, device) {
        if (!device) {
          return false;
        }
        user.device = null;
        return user.save(function(err) {
          if (err) {
            throw err;
          }
          return callback(true);
        });
      });
    };

    User.prototype.changePassword = function(newpassword, callback) {
      var p;
      if (!this.isAuthenticate) {
        return callback(false);
      }
      if (this.data == null) {
        return callback(false);
      }
      p = Crypto.createHash("sha256").update(newpassword).digest("hex");
      this.data.password = p;
      return this.data.save(function(err) {
        if (err) {
          throw err;
        }
        return callback(true);
      });
    };

    return User;

  })(BBObject);

  Group = (function(_super) {
    __extends(Group, _super);

    Group.prototype.data = {};

    Group.prototype.__data = {};

    function Group() {}

    Group.create = function(attrs, callback) {
      if (!attrs.name) {
        throw new Error("name is undefined");
      }
      if (!attrs.owner) {
        throw new Error("owner is undefined");
      }
      return GroupModel.findOne({
        name: attrs.name
      }).populate('members', 'username').exec(function(err, group) {
        var error, member, _i, _len, _ref;
        if (err) {
          throw err;
        }
        if (group) {
          error = new Error("group is existed");
          if (group) {
            return callback.call(group, error, group);
          }
        }
        group = new Group();
        group.data = new GroupModel();
        group.data.name = attrs.name;
        group.data.owners.push(attrs.owner.data._id);
        group.data.members = [];
        group.isChanged = true;
        if (attrs.members) {
          _ref = attrs.members;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            member = _ref[_i];
            group.data.members.push(member._id);
          }
        }
        return group.save(function() {
          return callback.call(group, null, group);
        });
      });
    };

    Group.find = function(attrs, callback) {
      var name;
      name = attrs.name;
      if (!name) {
        throw new Error("name is undefined");
      }
      return GroupModel.findOne({
        name: attrs.name
      }).populate('members', 'username').exec(function(err, group) {
        var error, g;
        if (err) {
          throw err;
        }
        if (!group) {
          error = new Error("group not found");
          return callback(error, null);
        }
        g = new Group();
        g.data = group;
        g.__data = _.clone(g.data);
        return callback.call(g, null, g);
      });
    };

    Group.prototype.fetch = function(callback) {
      if (!this.groupname || !this.data) {
        return false;
      }
      return GroupModel.findOne({
        name: this.groupname
      }, (function(_this) {
        return function(err, group) {
          if (err) {
            throw err;
          }
          if (!group) {
            callback(false);
          }
          _this.data.name = group.name;
          _this.data.members = group.members;
          return callback(_this.data);
        };
      })(this));
    };

    Group.prototype["delete"] = function(callback) {
      return GroupModel.findOne({
        name: this.get("name")
      }, function(err, group) {
        if (err) {
          throw err;
        }
        if (!group) {
          callback(false);
        }
        group.remove();
        return callback(true);
      });
    };

    Group.prototype.addMember = function(attrs, callback) {
      if (this instanceof Group) {
        return this._addMember(attrs, (function(_this) {
          return function(err, group) {
            _this.data = group;
            _this.__data = _.clone(_this.data);
            return callback.call(_this, err, _this);
          };
        })(this));
      } else {
        return this._addMember(attrs, callback);
      }
    };

    Group.prototype._addMember = function(attrs, callback) {
      var groupname, usernames;
      usernames = attrs.usernames;
      groupname = attrs.groupname || this.data.name;
      if (usernames == null) {
        return callback(new Error("user names is not undefined", null));
      } else if (groupname == null) {
        return callback(new Error("group name is not undefined", null));
      } else {
        return GroupModel.findOne({
          name: groupname
        }).exec((function(_this) {
          return function(err, group) {
            if (err) {
              throw err;
            }
            return UserModel.find({
              username: {
                $in: usernames
              }
            }, function(err, users) {
              var sFunc, sNode, user, _i, _len;
              if (err) {
                throw err;
              }
              sFunc = [];
              sNode = [];
              for (_i = 0, _len = users.length; _i < _len; _i++) {
                user = users[_i];
                group.members.addToSet(user._id);
                sNode.push(user);
                sFunc.push(function(cb) {
                  var u;
                  u = sNode.shift();
                  u.groups.addToSet(group._id);
                  return u.save(function(err) {
                    return cb(err, u);
                  });
                });
              }
              return group.save(function(err) {
                if (err) {
                  throw err;
                }
                return async.parallel(sFunc, function(err, results) {
                  if (err) {
                    throw err;
                  }
                  return callback.call(_this, null, group);
                });
              });
            });
          };
        })(this));
      }
    };

    Group.prototype.removeMember = function(attrs, callback) {
      if (this instanceof Group) {
        return this._removeMember(attrs, (function(_this) {
          return function(err, group) {
            _this.data = group;
            _this.__data - _.clone(_this.data);
            return callback.call(_this, err, _this);
          };
        })(this));
      } else {
        return this._removeMember(attrs, callback);
      }
    };

    Group.prototype._removeMember = function(attrs, callback) {
      if (attrs.usernames == null) {
        return callback(new Error("user names is not undefined", null));
      } else if (attrs.groupname == null) {
        return callback(new Error("group name is not undefined", null));
      } else {
        return UserModel.find({
          username: {
            $in: attrs.usernames
          }
        }, (function(_this) {
          return function(err, users) {
            if (err) {
              throw err;
            }
            return GroupModel.findOne({
              name: attrs.groupname
            }).exec(function(err, group) {
              var sFunc, sNode, user, _i, _len;
              if (err) {
                throw err;
              }
              sFunc = [];
              sNode = [];
              for (_i = 0, _len = users.length; _i < _len; _i++) {
                user = users[_i];
                group.members.pull(user._id);
                sNode.push(user);
                sFunc.push(function(cb) {
                  var u;
                  u = sNode.shift();
                  u.groups.pull(group._id);
                  return u.save(function(err) {
                    return cb(err, u);
                  });
                });
              }
              return group.save(function(err) {
                if (err) {
                  throw err;
                }
                return async.parallel(sFunc, function(err, results) {
                  if (err) {
                    throw err;
                  }
                  return callback.call(_this, null, group);
                });
              });
            });
          };
        })(this));
      }
    };

    Group.prototype.addOwner = function(attrs, callback) {
      if (attrs.ownernames == null) {
        return callback(new Error("owner's name is not undefined", null));
      } else if (attrs.groupname == null) {
        return callback(new Error("group's name is not undefined", null));
      } else {
        return UserModel.find({
          username: {
            $in: attrs.ownernames
          }
        }, (function(_this) {
          return function(err, users) {
            if (err) {
              throw err;
            }
            return GroupModel.findOne({
              name: attrs.groupname
            }, function(err, group) {
              var sFunc, sNode, user, _i, _len;
              if (err) {
                throw err;
              }
              sFunc = [];
              sNode = [];
              console.log("addowner-users");
              console.log(users);
              console.log(group);
              for (_i = 0, _len = users.length; _i < _len; _i++) {
                user = users[_i];
                group.owners.addToSet(user._id);
                sNode.push(user);
                sFunc.push(function(cb) {
                  var u;
                  u = sNode.shift();
                  u.groups.addToSet(group._id);
                  return u.save(function(err) {
                    return cb(err, u);
                  });
                });
              }
              return group.save(function(err) {
                if (err) {
                  throw err;
                }
                return async.parallel(sFunc, function(err, results) {
                  if (err) {
                    throw err;
                  }
                  return callback.call(_this, err, group);
                });
              });
            });
          };
        })(this));
      }
    };

    Group.prototype.removeOwner = function(attrs, callback) {
      if (this instanceof Group) {
        return this._removeOwner(attrs, (function(_this) {
          return function(err, group) {
            _this.data = group;
            _this.__data - _.clone(_this.data);
            return callback.call(_this, err, _this);
          };
        })(this));
      } else {
        return this._removeOwner(attrs, callback);
      }
    };

    Group.prototype._removeOwner = function(attrs, callback) {
      if (attrs.usernames == null) {
        return callback(new Error("owner's names is not undefined", null));
      } else if (attrs.groupname == null) {
        return callback(new Error("group name is not undefined", null));
      } else {
        return UserModel.find({
          username: {
            $in: attrs.usernames
          }
        }, (function(_this) {
          return function(err, users) {
            if (err) {
              throw err;
            }
            return GroupModel.findOne({
              name: attrs.groupname
            }).exec(function(err, group) {
              var sFunc, sNode, user, _i, _len;
              if (err) {
                throw err;
              }
              sFunc = [];
              sNode = [];
              for (_i = 0, _len = users.length; _i < _len; _i++) {
                user = users[_i];
                group.owners.pull(user._id);
                sNode.push(user);
                sFunc.push(function(cb) {
                  var u;
                  u = sNode.shift();
                  u.groups.pull(group._id);
                  return u.save(function(err) {
                    return cb(err, u);
                  });
                });
              }
              return group.save(function(err) {
                if (err) {
                  throw err;
                }
                return async.parallel(sFunc, function(err, results) {
                  if (err) {
                    throw err;
                  }
                  return callback.call(_this, null, group);
                });
              });
            });
          };
        })(this));
      }
    };

    Group.prototype.getMembers = function(callback) {
      var q;
      q = GroupModel.findOne({
        name: this.data.name
      });
      q.populate("members", "username device");
      return q.exec(function(err, group) {
        if (err) {
          throw err;
        }
        return callback(group.members);
      });
    };

    return Group;

  })(BBObject);

  ObjectModel = mongoose.model('object', new mongoose.Schema({
    attribute: {
      type: {}
    }
  }));

  UserModel = mongoose.model("user", new mongoose.Schema({
    username: {
      type: String
    },
    password: {
      type: String
    },
    attribute: {},
    device: {
      type: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "device"
      }
    },
    groups: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "group"
        }
      ]
    }
  }));

  GroupModel = mongoose.model("group", new mongoose.Schema({
    name: {
      type: String
    },
    attribute: {
      type: {}
    },
    owners: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "user"
        }
      ]
    },
    members: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "user"
        }
      ]
    }
  }));

  DeviceModel = mongoose.model("device", new mongoose.Schema({
    uuid: {
      type: String
    },
    type: {
      type: String
    },
    token: {
      type: String
    },
    endpoint: {
      type: String
    },
    owner: {
      type: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "user"
      }
    }
  }));

  module.exports = {
    User: User,
    Group: Group,
    Manager: new BabascriptManager()
  };

}).call(this);
