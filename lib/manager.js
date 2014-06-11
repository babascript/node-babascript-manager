(function() {
  var BabascriptManager, Crypto, Linda, LindaSocketIO, LocalStrategy, TupleSpace, async, direquire, express, mongoose, passport, path, redis, _;

  mongoose = require('mongoose');

  _ = require('underscore');

  Crypto = require('crypto');

  LindaSocketIO = require('linda-socket.io');

  LocalStrategy = require('passport-local').Strategy;

  express = require('express');

  passport = require('passport');

  async = require('async');

  redis = require('redis').createClient();

  direquire = require('direquire');

  path = require('path');

  Linda = LindaSocketIO.Linda;

  TupleSpace = LindaSocketIO.TupleSpace;

  BabascriptManager = (function() {
    function BabascriptManager() {
      console.log('init!');
    }

    BabascriptManager.prototype.attach = function(options) {
      if (options == null) {
        options = {};
      }
      this.io = options.io;
      this.server = options.server || this.io.server;
      this.app = options.app;
      if (this.io == null) {
        throw new Error('io not found');
      }
      if (this.server == null) {
        throw new Error('server not found');
      }
      if (this.app == null) {
        throw new Error('app not found');
      }
      this.linda = Linda.listen({
        io: this.io,
        server: this.server
      });
      this.app.use(function(req, res, next) {
        var headers, methods;
        headers = 'Content-Type, Authorization, Content-Length,';
        headers += 'X-Requested-With, Origin';
        methods = 'POST, PUT, GET, DELETE, OPTIONS';
        res.setHeader('Access-Control-Allow-Origin', req.headers.origin);
        res.setHeader('Access-Control-Allow-Credentials', true);
        res.setHeader('Access-Control-Allow-Methods', methods);
        res.setHeader('Access-Control-Request-Method', methods);
        res.setHeader('Access-Control-Allow-Headers', headers);
        return next();
      });
      this.app.set('events', direquire(path.resolve('src', 'events')));
      this.app.set('models', direquire(path.resolve('src', 'models')));
      this.app.set('helper', direquire(path.resolve('src', 'helper')));
      this.app.set('linda', this.linda);
      (require(path.resolve('src/events', 'user')))(this.app);
      (require(path.resolve('src/events', 'group')))(this.app);
      (require(path.resolve('src/events', 'websocket')))(this.app);
      if (((options != null ? options.secure : void 0) != null) === true) {
        console.log('set passport');
        return (require(path.resolve('src/events', 'session')))(this.app);
      }
    };

    return BabascriptManager;

  })();

  module.exports = new BabascriptManager();

}).call(this);
