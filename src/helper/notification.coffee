gcm = require 'node-gcm'
apn = require 'apn'
path = require 'path'
fs = require 'fs'
service = null

module.exports =

  sendNotification: (type, token, message) ->
    settings = require "../../settings.json"
    if type is 'android'
      message = new gcm.Message()
      sender = new gcm.Sender settings.google_api_key
      message.addData "message", message
      message.addData "title", "指令が来てます"
      message.addData 'msgcnt', 3
      message.timeToLive = 3000

      sender.send message, [token], 4, (result) ->
        console.log result
        return "ok"
    else if type is 'ios'
      service ?= new apn.connection
        gateway: "gateway.sandbox.push.apple.com"
        cer: fs.readFileSync path.resolve 'cert.pem'
        key: fs.readFileSync path.resolve 'key.pem'

      service.on "transmitted", (n, d) ->
        console.log "transmitted"
        console.log n
        console.log d

      service.on "transmissionError", (errcode, n, device) ->
        console.log 'transmissionError'
        console.log errcode
        console.log n
        console.log device

      device = new apn.Device token
      n = new apn.Notification()
      n.expiry = Math.floor(Date.now() / 1000) + 3600
      n.badge = 3
      n.alert = message

      service.pushNotification n, device
