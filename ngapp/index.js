(function() {
  var angular, io, ngmaterial, parser, reporterApp;

  angular = require("angular");

  require("angular-animate");

  require("angular-aria");

  require("angular-treemendous");

  ngmaterial = require("angular-material");

  io = require("socket.io-client");

  require("./index.css");

  parser = require("./specParser");

  reporterApp = angular.module("reporterApp", [ngmaterial, "treemendous"]);

  reporterApp.controller("appCtrl", function($scope, $mdToast, $sce) {
    var data, finished, progress, reload, socket, uri;
    uri = global.location.protocol + '//' + global.location.hostname + ':' + window.options.port;
    socket = io();
    socket.on("reload", function() {
      console.log("reloading");
      socket.close();
      return document.location.reload();
    });
    socket.emit("restartable");
    socket.once("restartable", function(isRestartable) {
      console.log("isRestartable: " + isRestartable);
      $scope.isRestartable = isRestartable;
      if (isRestartable) {
        return $scope.restart = function() {
          return socket.emit("restart");
        };
      }
    });
    $scope.splitNewLine = function(string) {
      return string.split("\n");
    };
    progress = function() {
      $scope.data = data.data;
      $scope.tree = data.tree;
      $scope.failed = data.failed;
      $scope.console = data.console;
      return $scope.$$phase || $scope.$digest();
    };
    finished = function() {
      $mdToast.show($mdToast.simple().content('Test finished'));
      socket.emit("loaded");
      console.log($scope.data);
      return console.log("finished");
    };
    reload = function() {
      return socket.emit("getConsole");
    };
    data = parser(socket, $sce, progress, finished);
    reload();
    return socket.on("reconnect", reload);
  });

  reporterApp.filter("hasProperty", function() {
    return function(array, property) {
      var i, len, obj, result;
      if (property) {
        result = [];
        for (i = 0, len = array.length; i < len; i++) {
          obj = array[i];
          if (obj[property]) {
            result.push(obj);
          }
        }
        return result;
      } else {
        return array;
      }
    };
  });

}).call(this);
