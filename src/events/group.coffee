_ = require 'lodash'

module.exports = (app) ->
  {User} = app.get "models"
  {Group} = app.get "models"

  app.post "/api/group/new", (req, res, next) ->
    name = req.body.name
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
    members = req.body.members
    Group.findOne {groupname: name}, (err, group) ->
      if err or !group?
        res.send 404, 'not found'
      else
        if !_.isArray members
          members = [members]
        User.find {username: {$in: members}}, (err, users) ->
          return res.send 404, 'error' if err
          ids = _.pluck users, "_id"
          for _id in ids
            group.members.addToSet _id
          group.save (err) ->
            return res.send 404, err if err
            res.send 201, group

  app.get "/api/group/:name/member", (req, res, next) ->
    name = req.params.name
    Group.findOne({groupname: name}).populate('members').exec (err, group) ->
      if err or !group?
        res.send 404, 'not found'
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
