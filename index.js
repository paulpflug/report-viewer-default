#!/usr/bin/env node
var path      = require('path'),
    events    = require('events'),
    readDir   = require('read-dir-simple'),
    optional  = require("optional"),
    watch     = optional("watch");

var dir = path.join(__dirname, "ngapp");
site = {
  files: readDir(dir, "utf8"),
  action: new events.EventEmitter(),
  reload: function(){
    site.files = readDir(dir, 'utf8')
    site.action.emit('reload')
  }
}
if (watch) {
  watch.watchTree(dir, site.reload);
}
module.exports = site
