# out: ../ngapp/index.js
angular = require("angular")
require("angular-animate")
require("angular-aria")
require("angular-treemendous")
ngmaterial = require("angular-material")
io = require("socket.io-client")
require("./index.css")

parser = require("./specParser")

reporterApp = angular.module "reporterApp", [ngmaterial,"treemendous"]

reporterApp.controller "appCtrl", ($scope,$mdToast,$sce) ->
  uri = global.location.protocol + '//' + global.location.hostname + ':' + window.options.port
  socket = io()

  socket.on "reload", () ->
    console.log "reloading"
    socket.close()
    document.location.reload()
  socket.emit "restartable"
  socket.once "restartable", (isRestartable) ->
    console.log "isRestartable: "+isRestartable
    $scope.isRestartable = isRestartable
    if isRestartable
      $scope.restart = () ->
        socket.emit "restart"

  $scope.splitNewLine = (string) ->
    return string.split("\n")
  progress = () ->
    $scope.data = data.data
    $scope.tree = data.tree
    $scope.failed = data.failed
    $scope.console = data.console
    $scope.$$phase || $scope.$digest()
  finished = () ->
    $mdToast.show($mdToast.simple().content('Test finished'))
    #socket.emit "setConsole", data.console
    socket.emit "loaded"
    console.log $scope.data
    console.log "finished"
  reload = () ->
    socket.emit "getConsole"

  data = parser(socket,$sce,progress,finished)

  reload()
  socket.on "reconnect", reload

reporterApp.filter "hasProperty", () ->
  return (array,property) ->
    if property
      result = []
      for obj in array
        if obj[property]
          result.push(obj)
      return result
    else
      return array
