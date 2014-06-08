(function() {
  var _;

  _ = require('lodash');

  module.exports = function(app) {
    var Group, User;
    User = app.get("models").User;
    Group = app.get("models").Group;
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
      members = req.body.members;
      return Group.findOne({
        groupname: name
      }, function(err, group) {
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
      }).populate('members').exec(function(err, group) {
        if (err || (group == null)) {
          return res.send(404, 'not found');
        } else {
          return res.send(200, group);
        }
      });
    });
    return app.del("/api/group/:name/member", function(req, res, next) {
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
  };

}).call(this);
