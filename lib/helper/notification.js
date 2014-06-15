(function() {
  var apn, fs, gcm, path, service;

  gcm = require('node-gcm');

  apn = require('apn');

  path = require('path');

  fs = require('fs');

  service = null;

  module.exports = {
    sendNotification: function(type, token, message) {
      var device, n, sender, settings;
      settings = require("../../settings.json");
      if (type === 'android') {
        message = new gcm.Message();
        sender = new gcm.Sender(settings.google_api_key);
        message.addData("message", message);
        message.addData("title", "指令が来てます");
        message.addData('msgcnt', 3);
        message.timeToLive = 3000;
        return sender.send(message, [token], 4, function(result) {
          console.log(result);
          return "ok";
        });
      } else if (type === 'ios') {
        if (service == null) {
          service = new apn.connection({
            gateway: "gateway.sandbox.push.apple.com",
            cer: fs.readFileSync(path.resolve('cert.pem')),
            key: fs.readFileSync(path.resolve('key.pem'))
          });
        }
        service.on("transmitted", function(n, d) {
          console.log("transmitted");
          console.log(n);
          return console.log(d);
        });
        service.on("transmissionError", function(errcode, n, device) {
          console.log('transmissionError');
          console.log(errcode);
          console.log(n);
          return console.log(device);
        });
        device = new apn.Device(token);
        n = new apn.Notification();
        n.expiry = Math.floor(Date.now() / 1000) + 3600;
        n.badge = 3;
        n.alert = message;
        return service.pushNotification(n, device);
      }
    }
  };

}).call(this);
