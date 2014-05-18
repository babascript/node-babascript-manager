(function() {
  var BBObject, BabascriptManager, Crypto, DeviceModel, Group, GroupModel, Linda, LindaSocketIO, LocalStrategy, TupleSpace, User, UserModel, express, mongoose, passport, _,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  mongoose = require('mongoose');

  mongoose.connect('mongodb://localhost/babascript/manager');

  _ = require('underscore');

  Crypto = require('crypto');

  LindaSocketIO = require('linda-socket.io');

  Linda = LindaSocketIO.Linda;

  TupleSpace = LindaSocketIO.TupleSpace;

  express = require('express');

  passport = require('passport');

  LocalStrategy = require('passport-local').Strategy;

  BabascriptManager = (function() {
    function BabascriptManager() {}

    BabascriptManager.prototype.attach = function(io, server, app) {
      var auth;
      this.io = io;
      this.server = server;
      this.app = app;
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
        io: io,
        server: server
      });
      this.linda.io.on('connection', (function(_this) {
        return function(socket) {
          socket.on('disconnect', _this.Socket.disconnect);
          socket.on('__linda_write', _this.Socket.write);
          socket.on('__linda_take', _this.Socket.take);
          return socket.on('__linda_cancel', _this.Socket.cancel);
        };
      })(this));
      passport.serializeUser(function(user, done) {
        var username;
        console.log('serializeUser');
        console.log(user);
        username = user.get('username');
        return done(null, user);
      });
      passport.deserializeUser(function(username, done) {
        console.log('deserializeUser');
        console.log(username);
        return done(err, username);
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
              return done(err);
            }
            if (!user) {
              return done(null, false, {
                message: 'invalid user'
              });
            } else {
              return done(null, user);
            }
          });
        };
      })(this)));
      this.app.use(passport.initialize());
      this.app.use(passport.session());
      auth = passport.authenticate('local', {
        successRedirect: '/',
        failureRedirect: '/api/session/failure',
        failureFlash: true
      });
      this.app.post('/api/session/login', function(req, res, next) {
        return auth(req, res, next);
      });
      this.app.get('/api/session', function(req, res, next) {
        if (req.session.passport.user != null) {
          return res.send(200);
        } else {
          return res.send(500);
        }
      });
      this.app.get('/api/session/success', function(req, res, next) {
        res.send(200);
        return res.end();
      });
      this.app.get('/api/session/failure', function(req, res, next) {
        console.log('failure');
        return res.send(500);
      });
      this.app.post('/api/user/new', (function(_this) {
        return function(req, res, next) {
          var attrs, password, username;
          console.log(req.body);
          username = req.param('username');
          password = req.param('password');
          attrs = {
            username: username,
            password: password
          };
          console.log(attrs);
          return _this.createUser(attrs, function(err, user) {
            if (err) {
              throw err;
            }
            return res.send(200);
          });
        };
      })(this));
      this.app.get('/api/user/:name', (function(_this) {
        return function(req, res, next) {
          return _this.getUser(req.params.name, function(err, user) {
            if (err) {
              return res.send(500);
            } else {
              return res.json(200, user);
            }
          });
        };
      })(this));
      this.app.put('/api/user/:name', function(req, res, next) {
        return res.send(200);
      });
      this.app["delete"]('/api/user/:name', function(req, res, next) {
        return res.send(200);
      });
      this.app.post('/api/group/new', function(req, res, next) {
        return res.send(200);
      });
      this.app.get('/api/group/:name', function(req, res, next) {
        return res.send(200);
      });
      this.app.put('/api/group/:name', function(req, res, next) {
        return res.send(200);
      });
      return this.app["delete"]('/api/group/:name', function(req, res, next) {
        return res.send(200);
      });
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
        if (err) {
          throw err;
        }
        return callback(null, user);
      });
    };

    return BabascriptManager;

  })();

  BBObject = (function() {
    function BBObject() {}

    BBObject.prototype.data = {};

    BBObject.prototype.__data = {};

    BBObject.prototype.save = function(callback) {
      var error;
      if ((this.data == null) || (this.__data == null)) {
        error = new Error('data is undefined');
        return callback(error, null);
      } else {
        return this.data.save((function(_this) {
          return function(err) {
            if (err) {
              _this.data = _this.__data;
              error = new Error('save error');
              return callback.call(_this, err);
            } else {
              _this.__data = _.clone(_this.data);
              return callback.call(_this, null);
            }
          };
        })(this));
      }
    };

    BBObject.prototype.set = function(key, value) {
      if (!(typeof key === 'string') && !(typeof key === 'number')) {
        throw new Error('key should be String or Number');
      }
      return this.data[key] = value;
    };

    BBObject.prototype.get = function(key) {
      if ((typeof key !== 'string') && (typeof key !== 'number')) {
        throw new Error('key should be String or Number');
      }
      return this.data[key];
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
          u.isAuthenticate = true;
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
        this.data = this.__data;
        return callback.call(this, error);
      }
      return User.__super__.save.call(this, callback);
    };

    User.prototype["delete"] = function(callback) {
      if (!this.isAuthenticate) {
        return callback(new Error("not authenticated"), false);
      }
      return this.data.remove(function(err, user) {
        if (err) {
          throw err;
        }
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

    User.prototype.changeTwitterAccount = function(newAccount, callback) {
      var username;
      if (!this.isAuthenticate) {
        return callback(false, null);
      }
      username = this.get("username");
      this.set("twitter", newAccount);
      return this.save(function(user) {
        return callback(true, user);
      });
    };

    User.prototype.changeMailAddress = function(newAddress, callback) {
      if (!this.isAuthenticate) {
        return callback(false, null);
      }
      this.set("mail", newAddress);
      return this.save(function(user) {
        return callback(true, user);
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
      }, function(err, group) {
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
        name: name
      }, function(err, group) {
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

    Group.prototype.addMembers = function(names, callback) {
      return UserModel.find({
        username: {
          $in: names
        }
      }, (function(_this) {
        return function(err, users) {
          var ids, members, newMembers;
          if (err) {
            throw err;
          }
          if (!users) {
            return callback(null);
          }
          ids = _.pluck(users, "_id");
          members = _.pluck(_this.data.members, "_id");
          return newMembers = _.union(ids, _this.data.members);
        };
      })(this));
    };

    Group.prototype.addMember = function(user, callback) {
      var id;
      if (!user) {
        throw new Error("arg[0] user is undefined");
      }
      id = user.get("_id");
      return UserModel.findById(id, (function(_this) {
        return function(err, user) {
          var member;
          if (err) {
            throw err;
          }
          if (!user) {
            return callback(null);
          }
          member = _.find(_this.data.members, function(m) {
            return m.toString() === user._id.toString();
          });
          if (!member) {
            _this.data.members.push(id);
          }
          return _this.data.save(function(err) {
            var group;
            if (err) {
              return callback(err, null);
            }
            id = _this.data._id;
            group = _.find(user.groups, function(group) {
              return group.toString() === id;
            });
            if (!group) {
              user.groups.push(id);
            }
            return user.save(function(err) {
              if (err) {
                return callback(err, null);
              }
              return GroupModel.populate(_this.data, {
                path: 'members'
              }, function(err, group) {
                _this.data = group;
                _this.__data = _.clone(_this.data);
                return callback.call(_this, null, _this);
              });
            });
          });
        };
      })(this));
    };

    Group.prototype.removeMember = function(user, callback) {
      var id;
      if (!user) {
        throw new Error("arg[0] user is undefined");
      }
      id = user.get("_id");
      return UserModel.findById(id, (function(_this) {
        return function(err, user) {
          var flag, i, _i, _ref;
          if (err) {
            throw err;
          }
          if (!user) {
            return callback(null);
          }
          flag = false;
          for (i = _i = 0, _ref = _this.data.members.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
            if (_this.data.members[i].toString() === user._id.toString()) {
              _this.data.members.splice(i, 1);
              break;
            }
          }
          return _this.data.save(function(err) {
            var _j, _ref1;
            if (err) {
              throw err;
            }
            for (i = _j = 0, _ref1 = user.groups.length - 1; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; i = 0 <= _ref1 ? ++_j : --_j) {
              if (user.groups[i].toString() === _this.data._id.toString()) {
                user.groups.splice(i, 1);
                break;
              }
            }
            return user.save(function(err) {
              if (err) {
                throw err;
              }
              return GroupModel.populate(_this.data, {
                path: "members"
              }, function(err, group) {
                _this.data = group;
                _this.__data = _.clone(_this.data);
                return callback.call(_this, null, _this);
              });
            });
          });
        };
      })(this));
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

  UserModel = mongoose.model("user", new mongoose.Schema({
    username: {
      type: String
    },
    password: {
      type: String
    },
    twitter: {
      type: String
    },
    mail: {
      type: String
    },
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
