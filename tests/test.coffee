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
          group.addMember user, (err, group) ->
            assert.equal err, null
            assert.ok group instanceof Group
            members = group.get 'members'
            assert.equal 1, members.length
            assert.equal user.get('username'), members[0].username
            done()

  it "remove group's member", (done) ->
    Manager.getGroup {name: test_group_name}, (err, group) ->
      assert.equal err, null
      Manager.getUser test_name, (err, user) ->
        group.removeMember user, (err, group) ->
          assert.equal err, null
          assert.ok group instanceof Group
          members = group.get 'members'
          assert.equal 0, members.length
          assert.equal null, members[0]
          done()

  it "delete group's", (done) ->
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
app.use (require 'body-parser')()
app.use (require 'method-override')()
app.use (req, res, next) ->
  app.locals.req = req
  return next null
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

app.use (req, res, next) ->
  console.log "hoge"
  next()

server = app.listen 3030
io = require('socket.io').listen server
name = test_name+'11'
mailaddress = 'test@babascript.org'
request = require 'request'
supertest = require 'supertest'
superagent = require 'superagent'
testUser = superagent.agent()
api = null
cookie = null
sessionID = ''

describe 'manager app test', ->

  before (done) ->
    console.log 'before'
    console.log "username: #{name}"
    console.log "password: #{test_pass}"
    Manager.createUser {username: name, password: test_pass}, (err, user) ->
      attrs =
        name: test_group_name
        owner: user
        members: user
      Manager.createGroup attrs, (err, group) ->

        done()
  after (done) ->
    done()

  it 'attach', (done) ->
    Manager.attach io, server, app
    # assert.ok io instanceof Socket.IO.clien
    assert.ok server instanceof http.Server
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

  it 'get data failure on not login', (done) ->
    api.get("/api/user/#{name}").expect(403).end done

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
    api.post('/api/user/new').send(data).expect(200).end done

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
    api.get("/api/user/#{n}").expect(500).end(done)

  it 'PUT /api/user/:name change mail addres', (done) ->
    data =
      mail: mailaddress
    api.put("/api/user/#{name}").send(data).expect(200).end done

  it "GET check modify /api/user/name", (done) ->
    api.get("/api/user/#{name}").expect(200).end (err, res) ->
      assert.equal res.body.data.username, name
      assert.equal res.body.data.mail, mailaddress
      done()

  it "PUT /api/user/:name change your password", (done) ->
    p = test_pass + '1101'
    data =
      password: p
    console.log p
    api.put("/api/user/#{name}").send().expect(200).end(done)

  it "GET check modify password", (done) ->
    failPass = test_pass
    successPass = test_pass + '1101'
    api.get("/api/user/#{name}").expect(200).end (err, res) ->
      # console.log res.body
      fail = Crypto.createHash("sha256").update(failPass).digest("hex")
      success = Crypto.createHash("sha256").update(successPass).digest("hex")
      assert.notEqual res.body.data.password, fail
      assert.equal res.body.data.password, success
      done()

  # it "DELETE /api/user/:name", (done) ->
  #   api.delete("/api/user/#{name}").send().expect(200).end(done)

  # it "POST /api/group/new", (done) ->
  #   api.post("/api/group/new").send().expect(200).end(done)

  # it "GET /api/group/:name", (done) ->
  #   done()

  # it "PUT /api/group/:name", (done) ->
  #   api.put("/api/group/#{group_name}").send().expect(200).end(done)

  # it "DELETE /api/user/:name", (done) ->
  #   api.delete("/api/group/#{group_name}").send().expect(200).end(done)

  # it "linda-test", (done) ->
  #   done()

  it 'Session logout', (done) ->
    api.delete('/api/session/logout').expect(200).end done
