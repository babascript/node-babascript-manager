_ = require 'lodash'

module.exports = (app) ->
  {User} = app.get "models"
  {Group} = app.get "models"
  {Task} = app.get "models"
  {TaskLog} = app.get "models"

  app.post "/api/group/new", (req, res, next) ->
    name = req.body.name
    res.send 404 if !name?
    Group.findOne {groupname: name}, (err, group) ->
      if err or group?
        res.send 404, 'already exist'
      else
        group = new Group
          groupname: name
        group.save (err) ->
          if err
            res.send 404
          else
            res.send 201, group

  app.del "/api/group/:name", (req, res, next) ->
    name = req.params.name
    Group.findOne {groupname: name}, (err, group) ->
      return res.send 404, 'err' if err
      return res.send 404, 'not exist' if !group?
      group.remove (err) ->
        if err
          res.send 404
        else
          res.send 200

  app.get "/api/group/:name", (req, res, next) ->
    name = req.params.name
    Group.findOne {groupname: name}, (err, group) ->
      if err or !group?
        res.send 404, 'not found'
      else
        res.send 200, group


  app.post "/api/group/:name/member", (req, res, next) ->
    name = req.params.name
    members = req.body.members|| req.body.username
    Group.findOne {groupname: name}, (err, group) ->
      if err or !group?
        res.send 404, 'not found'
      else
        if !_.isArray members
          members = [members]
        console.log members
        User.find {username: {$in: members}}, (err, users) ->
          console.log users
          return res.send 404, 'error' if err
          ids = _.pluck users, "_id"
          for _id in ids
            group.members.addToSet _id
          group.save (err) ->
            return res.send 404, err if err
            res.send 201, group

  app.get "/api/group/:name/member", (req, res, next) ->
    name = req.params.name
    Group.findOne({groupname: name})
    .populate('members', 'username attribute').exec (err, group) ->
      if err or !group?
        res.send 404, 'not found'
      else
        members = []
        for member in group.members
          members.push {
            username: member.username
            attribute: member.attribute
          }
        res.send 200, members

  app.del "/api/group/:name/member/:key", (req, res, next) ->
    name = req.params.name
    username = req.params.key
    Group.findOne({groupname: name}).exec (err, group) ->
      if err or !group?
        res.send 404, 'not found'
      else
        User.findOne {username: username}, (err, user) ->
          return res.send 404, 'error' if err
          group.members.pull user._id
          group.save (err) ->
            if err
              res.send 404, 'save errpr'
            else
              res.send 200, group


  app.del "/api/group/:name/member", (req, res, next) ->
    name = req.params.name
    members = req.body.members
    Group.findOne({groupname: name}).exec (err, group) ->
      if err or !group?
        res.send 404, 'not found'
      else
        if!_.isArray members
          members = [members]
        User.find {username: {$in: members}}, (err, users) ->
          return res.send 404, 'error' if err
          ids = _.pluck users, "_id"
          for _id in ids
            group.members.pull _id
          console.log group
          group.save (err) ->
            if err
              res.send 404, 'save errpr'
            else
              res.send 200, group

  app.get '/api/group/:name/tasks', (req, res, next) ->
    name = req.params.name
    Task.find({group: name}).sort('-createdAt')
    .exec (err, tasks) ->
      if err
        res.send 400
      else
        res.send 200, tasks

  app.get "/api/groups/all", (req, res, next) ->
    Group.find {}, (err, groups) ->
      if err
        res.send 400
      else
        res.send 200, groups

  app.get "/api/group/:name/tasklogs", (req, res, next) ->
    name = req.params.name
    TaskLog.find({name: name}).sort('-at').exec (err, task) ->
      console.log task
      res.send task
