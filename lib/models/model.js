(function() {
  var DeviceSchema, GroupSchema, ObjectSchema, Schema, TaskSchema, TeamSchema, TokenSchema, UserSchema, bcrypt, mongoose;

  mongoose = require('mongoose');

  bcrypt = require('bcrypt');

  Schema = mongoose.Schema;

  ObjectSchema = new Schema({
    attribute: {
      type: {}
    }
  });

  TeamSchema = new Schema({
    teamname: {
      type: String,
      required: true,
      index: {
        unique: true
      }
    },
    password: {
      type: String,
      required: true
    },
    users: {
      type: [
        {
          type: Schema.Types.ObjectId,
          ref: 'user'
        }
      ]
    },
    groups: {
      type: [
        {
          type: Schema.Types.ObjectId,
          ref: 'group'
        }
      ]
    },
    createAt: {
      type: Date,
      "default": Date.now
    }
  });

  TeamSchema.methods.comparePassword = function(candidatePass, cb) {
    return bcrypt.compare(candidatePass, this.password, function(err, isMatch) {
      if (err) {
        return cb(err);
      }
      return cb(null, isMatch);
    });
  };

  UserSchema = new Schema({
    username: {
      type: String
    },
    password: {
      type: String
    },
    attribute: {
      type: Schema.Types.Mixed,
      "default": {}
    },
    createdAt: {
      type: Date
    },
    updatedAt: {
      type: Date
    },
    token: {
      type: String
    },
    devicetype: {
      type: String
    },
    devicetoken: {
      type: String
    },
    tasks: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "task"
        }
      ]
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
  });

  UserSchema.methods.comparePassword = function(candidatePass, cb) {
    return bcrypt.compare(candidatePass, this.password, function(err, isMatch) {
      if (err) {
        return cb(err);
      }
      return cb(null, isMatch);
    });
  };

  UserSchema.pre('save', function(next) {
    var user;
    user = this;
    if (user.isModified("attribute")) {
      this.attrChange = true;
    }
    if (!user.isModified('password')) {
      next();
    }
    return bcrypt.genSalt(10, function(err, salt) {
      return bcrypt.hash(user.password, salt, function(err, hash) {
        if (err) {
          next(err);
        }
        user.password = hash;
        return next();
      });
    });
  });

  UserSchema.post("save", function(next) {
    var user;
    return user = this;
  });

  GroupSchema = new Schema({
    groupname: {
      type: String
    },
    attribute: {
      type: {}
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
  });

  TaskSchema = new Schema({
    text: {
      type: String
    },
    status: {
      type: String
    },
    worker: {
      type: String,
      "default": ""
    },
    cid: {
      type: String
    },
    key: {
      type: String
    },
    group: {
      type: String
    },
    startAt: {
      type: Date,
      "default": ""
    },
    finishAt: {
      type: Date,
      "default": ""
    },
    createdAt: {
      type: Date,
      "default": Date.now
    }
  });

  DeviceSchema = new Schema({
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
  });

  TokenSchema = new Schema({
    token: {
      type: String,
      required: true
    },
    createdAt: {
      type: Date,
      "default": Date.now
    }
  });

  module.exports = {
    User: mongoose.model("user", UserSchema),
    Group: mongoose.model("group", GroupSchema),
    Team: mongoose.model('team', TeamSchema),
    Task: mongoose.model("task", TaskSchema),
    Device: mongoose.model("device", DeviceSchema),
    Token: mongoose.model('token', TokenSchema),
    Object: mongoose.model('object', ObjectSchema)
  };

}).call(this);
