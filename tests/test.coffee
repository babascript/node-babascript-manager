fs = require 'fs'
path = require 'path'
assert = require 'assert'
request = require 'supertest'
Manager = require path.resolve 'src', 'manager'
Linda = require 'linda-socket.io'
SocketIOClient = require 'socket.io-client'

envs = [
  (path.resolve 'config', 'env.json')
  (path.resolve 'config', 'env.json.sample')
]

for env in envs when fs.existsSync env
  env = JSON.parse fs.readFileSync env, 'utf-8'
  process.env[k] = v for k, v of env
  break

app = require path.resolve 'tests', 'testapp'

describe 'user test', ->
  name = "baba_test"
  pass = 'takumi'

  before (done) ->
    done()

  after (done) ->
    console.log 'after'
    console.log Manager.server
    done()
    # Manager.server.close()

  it 'success new user', (done) ->
    data =
      username: name
      password: pass
    request(app).post('/api/user/new').send(data).expect(201).end done

  it 'get user', (done) ->
    request(app).get("/api/user/#{name}").expect(200).end done

  it 'user attribtue get', (done) ->
    request(app).get("/api/user/#{name}/attributes")
    .expect(200).end (err, res) ->
      assert.equal res.body[0].key, 'username'
      assert.equal res.body[0].value, name
      done()

  it 'user attribtuechange', (done) ->
    attribute =
      key: 'hoge'
      value: "fuga"
    request(app).put("/api/user/#{name}/attributes").send(attribute)
    .expect(200).end (err, res) ->
      request(app).get("/api/user/#{name}/attributes")
      .expect(200).end (err, res) ->
        console.log res.body
        done()

  it 'delete user', (done) ->
    data =
      password: pass
    request(app).del("/api/user/#{name}").send(data).expect(200).end done

describe 'group test', ->
  group_name = "masuilab_test_#{Date.now()}"
  user_name  = "baba_#{Date.now()}"
  pass = 'takumi'
  before (done) ->
    app.listen()
    k = 0
    for i in [0..9]
      request(app).post("/api/user/new")
      .send({username: "#{user_name}_#{i}", password: pass})
      .end (err, res) ->
        k += 1
        if k is 10
          console.log 'create!!'
          done()
  after (done) ->
    k = 0
    for i in [0..9]
      request(app).del("/api/user/#{user_name}_#{i}")
      .send({password: pass}).end (err, res) ->
        k += 1
        if k is 10
          console.log 'delete!!'
          done()

  it 'new group', (done) ->
    data =
      name: group_name
    request(app).post("/api/group/new").send(data).expect(201).end done

  it 'get group', (done) ->
    request(app).get("/api/group/#{group_name}")
    .expect(200).end (err, res) ->
      assert.equal group_name, res.body.groupname
      done()

  it 'add member group', (done) ->
    data =
      members: "#{user_name}_0"
    request(app).post("/api/group/#{group_name}/member").send(data)
    .expect(201).end (err, res) ->
      members = res.body.members
      assert.equal members.length, 1
      done()

  it 'get member', (done) ->
    request(app).get("/api/group/#{group_name}/member")
    .expect(200).end (err, res) ->
      members = res.body
      assert.equal members.length, 1
      assert.equal members[0].username, "#{user_name}_0"
      done()

  it 'remove member', (done) ->
    data =
      members: "#{user_name}_0"
    request(app).del("/api/group/#{group_name}/member").send(data)
    .expect(200).end done


  it 'add members group', (done) ->
    data =
      members: []
    for i in [1..9]
      data.members.push "#{user_name}_#{i}"
    request(app).post("/api/group/#{group_name}/member").send(data)
    .expect(201).end (err, res) ->
      members = res.body.members
      assert.equal members.length, 9
      done()

  it 'get member', (done) ->
    request(app).get("/api/group/#{group_name}/member")
    .expect(200).end (err, res) ->
      members = res.body
      assert.equal members.length, 9
      done()

  it 'remove members', (done) ->
    data =
      members: []
    for i in [1..9]
      data.members.push "#{user_name}_#{i}"
    request(app).del("/api/group/#{group_name}/member").send(data)
    .expect(200).end done


  it 'delete group', (done) ->
    request(app).del("/api/group/#{group_name}").expect(200).end done

# describe 'websocket', ->
#
#   it "virtual client test", (done) ->
#     linda = app.get 'linda'
#     io = SocketIOClient.connect "http://localhost:9080/"
#     io.once "connection", ->
#       console.log 'ok'
#       done()
