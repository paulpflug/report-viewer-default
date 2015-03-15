angular = require("angular")
require("angular-animate")
require("angular-aria")
require("angular-treemendous")
ngmaterial = require("angular-material")
io = require("socket.io-client")
require("./index.css")

reporterApp = angular.module "reporterApp", [ngmaterial,"treemendous"]

reporterApp.controller "appCtrl", ($scope,$mdToast) ->
  socket = io()
  $scope.data = []
  $scope.tree = {branches:[]}
  $scope.failed = []
  levels = []
  $scope.count = 0
  $scope.tests = 0
  socket.on "reload", () ->
    console.log "reloading"
    document.location.reload()

  $scope.splitNewLine = (string) ->
    return string.split("\n")

  parse = (data) ->
    if data and data[0]
      if data[0] == "start"
        $scope.data = []
        $scope.failed = []
        $scope.tree = {branches:[]}
        count = data[0][1].total
      else if data[0] == "fail"
        $scope.failed.push(data[1])
      else if data[0] == "pass"
        $scope.data.push(data[1])
      else if data[0] == "end"
        $scope.count = $scope.data.length
        $scope.tests = data[1].tests
        $mdToast.show($mdToast.simple().content('Test finished'))
      if data[0] == "fail" or data[0] == "pass"
        identifier = data[1].fullTitle.replace(data[1].title,"").replace(/\s+$/,"")
        difference = identifier
        newlevels = []
        for lvl in levels
          if identifier.indexOf(lvl) > -1
            difference = difference.replace(lvl,"").replace(/^s+/,"")
            newlevels.push lvl
        if difference
          newlevels.push difference
        data[1].levels = newlevels
        levels = newlevels.slice()
        return data[1]
  addtotree = (data) ->
    if data.levels
      current = $scope.tree
      last = null
      for lvl in data.levels
        found = false
        for branch in current.branches
          if branch.name == lvl
            last = current
            current = branch
            found = true
            break 
        if not found
          last = current
          newBranch = {name:lvl,branches:[],leaves:[],duration:0}
          current.branches.push newBranch
          current = newBranch
      current.leaves.push data
      current.duration += data.duration

  reload = () ->
    $scope.data = []
    $scope.tree = {branches:[]}
    socket.emit "data"
  reload()

  socket.on "data", (data) ->
    for dataChunk in data
      parsed = parse(dataChunk)
      if parsed
        addtotree(parsed)
    $scope.$$phase || $scope.$digest()

  socket.on "dataChunk", (dataChunk) ->
    parsed = parse(dataChunk)
    if parsed
      addtotree(parsed)
    $scope.$$phase || $scope.$digest()

  socket.on "dataConsole", (dataConsole) ->
    console.log "From console: "+ dataConsole

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