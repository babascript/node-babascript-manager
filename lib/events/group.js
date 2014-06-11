(function() {
  var _;

  _ = require('lodash');

  module.exports = function(app) {
    var Group, Task, User;
    User = app.get("models").User;
    Group = app.get("models").Group;
    Task = app.get("models").Task;
    app.post("/api/group/new", function(req, res, next) {
      var name;
      name = req.body.name;
      return Group.findOne({
        groupname: name
      }, function(err, group) {
        if (err || (group != null)) {
          return res.send(404, 'already exist');
        } else {
          group = new Group({
            groupname: name
          });
          return group.save(function(err) {
            if (err) {
              return res.send(404);
            } else {
              return res.send(201, group);
            }
          });
        }
      });
    });
    app.del("/api/group/:name", function(req, res, next) {
      var name;
      name = req.params.name;
      return Group.findOne({
        groupname: name
      }, function(err, group) {
        if (err) {
          return res.send(404, 'err');
        }
        if (group == null) {
          return res.send(404, 'not exist');
        }
        return group.remove(function(err) {
          if (err) {
            return res.send(404);
          } else {
            return res.send(200);
          }
        });
      });
    });
    app.get("/api/group/:name", function(req, res, next) {
      var name;
      name = req.params.name;
      return Group.findOne({
        groupname: name
      }, function(err, group) {
        if (err || (group == null)) {
          return res.send(404, 'not found');
        } else {
          return res.send(200, group);
        }
      });
    });
    app.post("/api/group/:name/member", function(req, res, next) {
      var members, name;
      name = req.params.name;
      members = req.body.members || req.body.username;
      return Group.findOne({
        groupname: name
      }, function(err, group) {
        if (err || (group == null)) {
          return res.send(404, 'not found');
        } else {
          if (!_.isArray(members)) {
            members = [members];
          }
          console.log(members);
          return User.find({
            username: {
              $in: members
            }
          }, function(err, users) {
            var ids, _i, _id, _len;
            console.log(users);
            if (err) {
              return res.send(404, 'error');
            }
            ids = _.pluck(users, "_id");
            for (_i = 0, _len = ids.length; _i < _len; _i++) {
              _id = ids[_i];
              group.members.addToSet(_id);
            }
            return group.save(function(err) {
              if (err) {
                return res.send(404, err);
              }
              return res.send(201, group);
            });
          });
        }
      });
    });
    app.get("/api/group/:name/member", function(req, res, next) {
      var name;
      name = req.params.name;
      return Group.findOne({
        groupname: name
      }).populate('members', 'username attribute').exec(function(err, group) {
        var member, members, _i, _len, _ref;
        if (err || (group == null)) {
          return res.send(404, 'not found');
        } else {
          members = [];
          _ref = group.members;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            member = _ref[_i];
            members.push({
              username: member.username,
              attribute: member.attribute
            });
          }
          return res.send(200, members);
        }
      });
    });
    app.del("/api/group/:name/member/:key", function(req, res, next) {
      var name, username;
      name = req.params.name;
      username = req.params.key;
      return Group.findOne({
        groupname: name
      }).exec(function(err, group) {
        if (err || (group == null)) {
          return res.send(404, 'not found');
        } else {
          return User.findOne({
            username: username
          }, function(err, user) {
            if (err) {
              return res.send(404, 'error');
            }
            group.members.pull(user._id);
            return group.save(function(err) {
              if (err) {
                return res.send(404, 'save errpr');
              } else {
                return res.send(200, group);
              }
            });
          });
        }
      });
    });
    app.del("/api/group/:name/member", function(req, res, next) {
      var members, name;
      name = req.params.name;
      members = req.body.members;
      return Group.findOne({
        groupname: name
      }).exec(function(err, group) {
        if (err || (group == null)) {
          return res.send(404, 'not found');
        } else {
          if (!_.isArray(members)) {
            members = [members];
          }
          return User.find({
            username: {
              $in: members
            }
          }, function(err, users) {
            var ids, _i, _id, _len;
            if (err) {
              return res.send(404, 'error');
            }
            ids = _.pluck(users, "_id");
            for (_i = 0, _len = ids.length; _i < _len; _i++) {
              _id = ids[_i];
              group.members.pull(_id);
            }
            console.log(group);
            return group.save(function(err) {
              if (err) {
                return res.send(404, 'save errpr');
              } else {
                return res.send(200, group);
              }
            });
          });
        }
      });
    });
    app.get('/api/group/:name/tasks', function(req, res, next) {
      var name;
      name = req.params.name;
      return Task.find({
        group: name
      }).sort('-createdAt').exec(function(err, tasks) {
        if (err) {
          return res.send(400);
        } else {
          return res.send(200, tasks);
        }
      });
    });
    return app.get("/api/groups/all", function(req, res, next) {
      return Group.find({}, function(err, groups) {
        if (err) {
          return res.send(400);
        } else {
          return res.send(200, groups);
        }
      });
    });
  };

}).call(this);
