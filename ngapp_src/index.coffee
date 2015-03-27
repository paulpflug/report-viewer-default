angular = require("angular")
require("angular-animate")
require("angular-aria")
require("angular-treemendous")
ngmaterial = require("angular-material")
io = require("socket.io-client")
require("./index.css")

reporterApp = angular.module "reporterApp", [ngmaterial,"treemendous"]

reporterApp.controller "appCtrl", ($scope,$mdToast,$sce) ->

  socket = io()
  reset = () ->
    $scope.data = []
    $scope.tree = {
      level: []
      branches:[]
    }
    $scope.failed = []
    $scope.console = []
  reset()
  
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
        reset()
        count = data[0][1].total
      else if data[0] == "fail"
        $scope.failed.push(data[1])
      else if data[0] == "pass"
        $scope.data.push(data[1])
      else if data[0] == "end"
        $scope.count = $scope.data.length
        $scope.tests = data[1].tests
        $mdToast.show($mdToast.simple().content('Test finished'))
        loaded()
      if data[0] == "fail" or data[0] == "pass"
        if data[1].levels
          return data[1]
        else
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
          level = current.level.slice(0)
          level.push(level.length)
          newBranch = {
            name:lvl
            branches:[]
            leaves:[]
            level: level
          }
          current.branches.push newBranch
          current = newBranch
      current.leaves.push data


  parseConsole = (consoleChunk) ->
    return $sce.trustAsHtml("<br>") if not consoleChunk.text
    return $sce.trustAsHtml(consoleChunk.text.replace(/ /g,"&nbsp;"))

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

  socket.on "console", (console) ->
    for consoleChunk,i in console
      consoleChunk.id = i
      consoleChunk.text = parseConsole(consoleChunk)
      $scope.console.push consoleChunk
    $scope.$$phase || $scope.$digest()

  socket.on "consoleChunk", (consoleChunk) ->
    consoleChunk.id = $scope.console.length
    consoleChunk.text = parseConsole(consoleChunk)
    $scope.console.push consoleChunk
    $scope.$$phase || $scope.$digest()

  socket.on "errorChunk", (errorChunk) ->
    for d in $scope.failed
      if d.failure and d.failure == errorChunk.id
        d.failure = errorChunk.text.join("\n")

  reload = () ->
    socket.emit "data"
    socket.emit "console"
  loaded = () ->
    socket.emit "loaded"
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