process.env.NODE_ENV = 'test'

path = require 'path'
assert = require 'assert'
Crypto = require 'crypto'
Manager = require path.resolve './lib/manager'
User = Manager.User
Group = Manager.Group
Manager = Manager.Manager
_    = require 'underscore'
http = require 'http'
url = require 'url'
mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/babascript/manager'

express = require 'express'
session = require 'express-session'
MongoStore = require('connect-mongo')(session)
passport = require 'passport'
async = require "async"

test_name = "baba_test_#{Date.now()}"
test_pass = "hoge_fuga_#{Date.now()}"
test_group_name = "test_group_#{Date.now()}"

describe "manager program test", ->

  it 'manager create', (done) ->
    assert.notEqual Manager, null
    done()

  it 'User Create', (done) ->
    attrs =
      username: test_name
      password: test_pass
    Manager.createUser attrs, (err, user) ->
      assert.equal err, null
      assert.ok user instanceof User
      username = user.get('username')
      assert.equal test_name, user.get 'username'
      p = Crypto.createHash('sha256').update(test_pass).digest('hex')
      assert.equal p, user.get('password')
      done()

  it 'User get', (done) ->
    Manager.getUser test_name, (err, user) ->
      assert.equal err, null
      assert.ok user instanceof User
      assert.equal test_name, user.get('username')
      done()

  it 'User authenticate', (done) ->
    Manager.getUser test_name, (err, user) ->
      user.authenticate test_pass, (result) ->
        assert.ok result
        assert.ok user.isAuthenticate
        done()

  it 'User authenticate fail', (done) ->
    Manager.getUser test_name, (err, user) ->
      user.authenticate test_pass+'010101001', (result) ->
        assert.ok !result
        assert.ok !user.isAuthenticate
        done()

  it 'User password modify', (done) ->
    Manager.getUser test_name, (err, user) ->
      user.authenticate test_pass, (result) ->
        assert.ok result
        oldpass = user.get 'password'
        newpass = test_pass+'0101'
        user.changePassword newpass, (result) ->
          _newpass = Crypto.createHash('sha256').update(newpass).digest 'hex'
          p = user.get 'password'
          assert.ok result
          assert.notEqual p, oldpass
          assert.equal p, _newpass
          test_pass = test_pass+'0101'
          done()

  it 'User password modify fail', (done) ->
    Manager.getUser test_name, (err, user) ->
      p = test_pass+'hogefugahogefuga'
      user.authenticate p, (result) ->
        assert.ok !result
        p += 'hoge'
        user.changePassword p, (result) ->
          assert.ok !result
          done()

  it 'attributes: User twitter account modify', (done) ->
    twittername = 'takumibaba'
    Manager.getUser test_name, (err, user) ->
      user.authenticate test_pass, (result) ->
        assert.ok result
        user.set 'twitter', twittername
        user.save (err) ->
          assert.equal err, null
          assert.equal @get('twitter'), twittername
          assert.equal @get('username'), test_name
          done()

  it "attributes: get user's twitter account", (done) ->
    Manager.getUser test_name, (err, user) ->
      account = user.get 'twitter'
      assert.equal account, 'takumibaba'
      done()

  it 'attributes: User twitter account modify fail', (done) ->
    twittername = 'takumibaba12'
    Manager.getUser test_name, (err, user) ->
      user.set 'twitter', twittername
      user.save (err) ->
        assert.ok err instanceof Error
        assert.equal 'takumibaba', @get 'twitter'
        done()

  it 'attributes: User mail address modify', (done) ->
    Manager.getUser test_name, (err, user) ->
      user.authenticate test_pass, (result) ->
        assert.ok result
        user.set 'mail', 'mail@babascript.org'
        user.save (err) ->
          assert.equal err, null
          assert.equal 'mail@babascript.org', @get 'mail'
          assert.ok @ instanceof User
          Manager.getUser test_name, (err, u) ->
            assert.equal 'mail@babascript.org', u.get "mail"
            done()

  it "attributes: get user's mail account", (done) ->
    Manager.getUser test_name, (err, user) ->
      assert.equal 'mail@babascript.org', user.get "mail"
      done()

  it 'attributes: mail address modify failed', (done) ->
    mailaddress = 'mail22@babascript.org'
    Manager.getUser test_name, (err, user) ->
      user.set 'mail', mailaddress
      user.save (err) ->
        assert.ok err instanceof Error
        assert.equal @, user
        assert.ok @ instanceof User
        done()

  it 'manager-user delete', (done) ->
    Manager.getUser test_name, (err, user) ->
      user.authenticate test_pass, (result) ->
        assert.ok result
        name = user.get 'username'
        assert.ok user instanceof User
        assert.equal name, user.get('username')
        user.delete (err, result) ->
          assert.equal err, null
          assert.ok result
          Manager.getUser test_name, (err, user) ->
            assert.equal user, null
            done()

  it 'create new group', (done) ->
    params =
      username: test_name
      password: test_pass
    Manager.createUser params, (err, user) ->
      attrs =
        name: test_group_name
        owner: user
        members: user
      assert.ok user instanceof User
      Manager.createGroup attrs, (status, group) ->
        assert.ok group instanceof Group
        assert.equal group.get('name'), test_group_name
        assert.equal group.get('owners').shift(), user.get '_id'
        done()

  it 'get group', (done) ->
    Manager.getGroup {name: test_group_name}, (err, group) ->
      assert.equal err, null
      assert.ok group instanceof Group
      name = group.get 'name'
      assert.equal name, test_group_name
      done()

  it "add group's member", (done) ->
    Manager.getGroup {name: test_group_name}, (err, group) ->
      assert.equal err, null
      assert.equal 0, group.get('members').length
      Manager.getUser test_name, (err, user) ->
        user.authenticate test_pass, (result) ->
          assert.ok result
          _id = user.get "_id"
          username = user.get "username"
          attrs =
            usernames: [username]
          group.addMember attrs, (err, group) ->
            assert.equal err, null
            assert.ok group instanceof Group
            members = group.get 'members'
            assert.equal 1, members.length
            assert.deepEqual members[0], _id
            done()

  it "remove group's member", (done) ->
    Manager.getGroup {name: test_group_name}, (err, group) ->
      assert.equal err, null
      Manager.getUser test_name, (err, user) ->
        id = user.get "_id"
        name = user.get "username"
        data =
          groupname: test_group_name
          usernames: [name]
        group.removeMember data, (err, group) ->
          assert.equal err, null
          assert.ok group instanceof Group
          members = group.get 'members'
          assert.equal 0, members.length
          assert.equal null, members[0]
          done()

  it "remove group's owner", (done) ->
    Manager.getGroup {name: test_group_name}, (err, group) ->
      assert.equal err, null
      attrs =
        groupname: test_group_name
        ownernames: [test_name]
      group.removeOwner attrs, (err, group) ->
        assert.equal err, null
        assert.ok group instanceof Group
        owners = group.get 'owners'
        assert.equal 0, owners.length
        assert.equal null, owners[0]
        done()

  it "delete group", (done) ->
    return done()
    Manager.getGroup {name: test_group_name}, (err, group) ->
      assert.ok group instanceof Group
      name = group.get 'name'
      assert.equal name, test_group_name
      Manager.getUser test_name, (user) ->
        user.authenticate test_pass, (result) ->
          assert.ok result
          group.delete test_group_name, user, (result) ->
            assert.ok result
            user.delete (err, result) ->
              assert.equal err, null
              assert.ok result
              done()

app = express()
app.use (require 'morgan')('dev') if 'off' isnt process.env.NODE_LOG
app.use (require 'body-parser')()
app.use (require 'method-override')()
# app.use (req, res, next) ->
#   app.locals.req = req
#   return next null
app.use require('cookie-parser')()

app.use (req, res, next) ->
  headers = 'Content-Type, Authorization, Content-Length,'
  headers += 'X-Requested-With, Origin'
  methods = 'POST, PUT, GET, DELETE, OPTIONS'
  res.setHeader 'Access-Control-Allow-Origin', '*'
  res.setHeader 'Access-Control-Allow-Credentials', true
  res.setHeader 'Access-Control-Allow-Methods', methods
  res.setHeader 'Access-Control-Request-Method', methods
  res.setHeader 'Access-Control-Allow-Headers', headers
  next()

app.use session
  secret: 'session:hogefuga'
  store: new MongoStore
    db: 'localhost'
  cookie:
    httpOnly: false
    maxAge: 1000*60*60*24*7

server = null
io = null
name = test_name+'11'
name_owner = name + "owner"
mailaddress = 'test@babascript.org'
request = require 'request'
supertest = require 'supertest'
request = require 'superagent'
# testUser = superagent.agent()
api = null
cookie = null
sessionID = ''

describe 'manager app test', ->

  before (done) ->
    server = app.listen 3030
    io = require('socket.io').listen server
    Manager.createUser {username: name, password: test_pass}, (err, user) ->
      attrs =
        name: test_group_name
        owner: user
        members: user
      Manager.createGroup attrs, (err, group) ->
        done()
  after (done) ->
    # server.close()
    # io.disconnect()
    done()

  it 'attach', (done) ->
    Manager.attach {io: io, app: app, server: io.server}
    # assert.ok io instanceof Socket.IO.clien
    # assert.ok app instanceof express
    api = supertest.agent app
    done()

  it 'session: login failure', (done) ->
    p = test_pass+'failure'
    data =
      username: name
      password: p
    api.post('/api/session/login').send(data).expect(302).end (err, res) ->
      done()

  # it 'get data failure on not login', (done) ->
  #   api.get("/api/user/#{name}").expect(403).end done

  it 'Session:login', (done) ->
    data =
      username: name
      password: test_pass
    api.post('/api/session/login').send(data).expect(302).end (err, res) ->
      assert.equal res.header.location, '/'
      done()

  it 'Session isLogin?', (done) ->
    data =
      username: name
      password: test_pass
    api.get('/api/session').expect(200).end (err, res) ->
      throw err if err
      done()

  it 'POST /api/user/new', (done) ->
    data = {username: name+'9898', password: test_pass+'9898'}
    api.post('/api/user/new').send(data).expect(201).end done

  it 'POST /api/user/new fail', (done) ->
    data = {usernme: name}
    api.post('/api/user/new').send(data).expect(500).end done

  it 'GET /api/user/:name', (done) ->
    n = name + '9898'
    api.get("/api/user/#{n}").expect(200).end (err, res) ->
      assert.equal err, null
      assert.equal res.body.data.username, name+'9898'
      done()

  it 'GET /api/user/:name fail', (done) ->
    n = name+"fail"
    api.get("/api/user/#{n}").expect(404).end(done)

  it 'PUT /api/user/:name change mail address', (done) ->
    data =
      mail: mailaddress
    api.put("/api/user/#{name}").send(data).expect(200).end done

  it "GET check modify /api/user/name", (done) ->
    api.get("/api/user/#{name}").expect(200).end (err, res) ->
      console.log res.body.data
      assert.equal res.body.data.username, name
      assert.equal res.body.data.attribute.mail, mailaddress
      done()

  it "PUT /api/user/:name change your password", (done) ->
    p = test_pass + '1101'
    data =
      password: p
    api.put("/api/user/#{name}").send(data).expect(200).end(done)

  it "GET check modify password", (done) ->
    failPass = test_pass
    successPass = test_pass + '1101'
    api.get("/api/user/#{name}").expect(200).end (err, res) ->
      fail = Crypto.createHash("sha256").update(failPass).digest("hex")
      success = Crypto.createHash("sha256").update(successPass).digest("hex")
      assert.notEqual res.body.data.password, fail
      assert.equal res.body.data.password, success
      done()

  it "DELETE /api/user/:name", (done) ->
    p = test_pass + '1101'
    data =
      username: name
      password: p
    api.delete("/api/user/#{name}").send(data).expect(200).end(done)

  it "check user delete", (done) ->
    api.get("/api/user/#{name}").expect(404).end done

  it "GET /api/group/:name", (done) ->
    api.get("/api/group/#{test_group_name}").expect(200).end (err, res) ->
      assert.equal res.body.data.name, test_group_name
      done()

  it "GET /api/group/:name fail", (done) ->
    n = test_group_name+"hoge"
    api.get("/api/group/#{n}").expect(404).end done

  it "PUT /api/group/:name", (done) ->
    return done()
    api.put("/api/group/#{test_group_name}").send(data).expect(200).end done

  it "POST /api/group/:name/member", (done) ->
    attrs =
      username: name + '0'
      password: test_pass + '0'
    api.post("/api/user/new").send(attrs).expect(200).end (err, res) ->
      _id = res.body.data._id
      param =
        names: [res.body.data.username]
      setImmediate ->
        api.post("/api/group/#{test_group_name}/member")
        .send(param).expect(200).end (err, res) ->
          throw err if err
          setImmediate ->
            api.get("/api/group/#{test_group_name}")
            .expect(200).end (err, res) ->
              members = res.body.data.members
              assert.equal members.length, 1
              assert.equal members[0]._id, _id
              done()

  it "DELETE /api/group/:name/member", (done) ->
    n = name + '0'
    data =
      names: [n]
    api.del("/api/group/#{test_group_name}/member").send(data)
    .expect(200).end (err, res) ->
      throw err if err
      setImmediate ->
        api.get("/api/group/#{test_group_name}")
        .expect(200).end (err, res) ->
          members = res.body.data.members
          assert.equal members.length, 0
          done()

  it "add group members", (done) ->
    aFunc = []
    attrslist = []
    NUM = 10
    for i in [1..NUM]
      attrslist.push
        username: name + i
        password: test_pass + i
      aFunc.push (cb) ->
        attrs = attrslist.shift()
        api.post("/api/user/new").send(attrs).expect(200).end (err, res) ->
          data =  res.body.data
          _id = data._id
          setImmediate ->
            cb null, data.username
    async.series aFunc, (err, results) ->
      setImmediate ->
        param =
          names: results
        api.post("/api/group/#{test_group_name}/member")
        .send(param).expect(200).end (err, res) ->
          throw err if err
          setImmediate ->
            api.get("/api/group/#{test_group_name}")
            .expect(200).end (err, res) ->
              members = res.body.data.members
              done()

  it "DELETE users /api/group/:name/members", (done) ->
    groupname = test_group_name
    names = []
    NUM = 10
    for i in [1..NUM]
      names.push name + i
    data =
      names: names
    api.del("/api/group/#{groupname}/member").send(data).expect(200)
    .end (err, res) ->
      throw err if err
      setImmediate ->
        api.get("/api/group/#{groupname}").expect(200).end (err, res) ->
          members = res.body.data.members
          assert.equal members.length, 0
          done()

  it "add group owner", (done) ->
    attrs =
      username: name_owner + '0'
      password: test_pass + '0'
    api.post("/api/user/new").send(attrs).expect(200).end (err, res) ->
      _id = res.body.data._id
      param =
        ownernames: [res.body.data.username]
      setImmediate ->
        api.post("/api/group/#{test_group_name}/owner")
        .send(param).expect(200).end (err, res) ->
          throw err if err
          setImmediate ->
            api.get("/api/group/#{test_group_name}")
            .expect(200).end (err, res) ->
              owners = res.body.data.owners
              assert.equal owners.length, 1
              assert.equal owners[0], _id
              done()

  it "remove group owner", (done) ->
    param =
      ownernames: [name_owner+'0']
    api.del("/api/group/#{test_group_name}/owner")
    .send(param).expect(200).end (err, res) ->
      throw err if err
      setImmediate ->
        api.get("/api/group/#{test_group_name}")
        .expect(200).end (err, res) ->
          owners = res.body.data.owners
          assert.equal owners.length, 0
          done()

  it "modify attribute", (done) ->
    param =
      baba: 'takumi'
    api.put("/api/group/#{test_group_name}").send(param)
    .expect(200).end (err, res) ->
      throw err if err
      setImmediate ->
        api.get("/api/group/#{test_group_name}").expect(200).end (err, res) ->
          assert.equal err, null
          assert.deepEqual res.body.data.attribute, param
          done()

  it 'Session logout', (done) ->
    api.delete('/api/session/logout').expect(200).end done

option =
  linda: "localhost:3030"
baba = new (require('babascript'))("baba_tests", option)
client = new (require('babascript-client'))("baba_tests", option)

describe 'babascript websocket test', ->

  it "normal task test", (done) ->
    client.on "get_task", (result) ->
      console.log result
      @returnValue true
    baba.こんばんわ {format: "boolean"}, (result) ->
      assert.ok result.value
      done()
