# out: ../ngapp/specParser.js
datetimeRegex = /^(?:\s*(Sun|Mon|Tue|Wed|Thu|Fri|Sat),\s*)?(0?[1-9]|[1-2][0-9]|3[01])\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(19[0-9]{2}|[2-9][0-9]{3}|[0-9]{2})\s+(2[0-3]|[0-1][0-9]):([0-5][0-9])(?::(60|[0-5][0-9]))?\s+([-\+][0-9]{2}[0-5][0-9]|(?:UT|GMT|(?:E|C|M|P)(?:ST|DT)|[A-IK-Z]))\s*/

getDuration = (string) ->
  duration = string.match(/\((\d+m?s)\)/)
  duration = duration[1] if duration
  return duration

module.exports = (socket,sce, progress, finished) ->
  console.log "in parser"
  addtotree = (data) ->
    if data.levels
      current = result.tree
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
  addError = () ->
    for d in result.failed
      if d.failure and d.failure == state.error.id
        d.failure = state.error.text.join("\n")
    if result.failed.length == parseInt(state.error.id)
      console.log "calling finished"
      finished()
    console.log "failed "+result.failed.length+" errorid "+state.error.id
  result = {}
  state = {}
  reset = () ->
    console.log "resetting data"
    result.data = []
    result.tree = {
      level: []
      branches: []
    }
    result.failed = []
    result.console = []
    result.duration = ""
    state.levels = []
    state.indent = 0
    state.inTest = true
    state.inError = 0
    state.error = {}
  reset()
  socket.on "restart", reset
  parseLine = (cLine) ->
    console.log cLine
    if cLine.text.indexOf("\u001b")> -1
      cLine.text = ""
      reset()
    else
      if cLine.text != ""
        currentIndent = cLine.text.match(/(^\s*)/)[1].length
        if currentIndent > 1
          name = cLine.text.substring(currentIndent)
          if state.inTest
            if name[0] == "✓" # successful test
              name = name.substring(2)
              item = {
                type: "pass"
                title: name
                fullTitle: state.levels.join(" ") + " "+ name
                levels: state.levels.slice()
                duration: getDuration(name)
              }
              result.data.push item
              addtotree item
              cLine.type = "pass"

            else if name.search(/^\d+\)/) > -1 # failed test
              id = name.match(/(^\d+)\)/)[1]
              name = name.replace(/^\d+\)/, "")
              item = {
                type: "fail"
                title: name
                fullTitle: state.levels.join(" ") + " "+ name
                levels: state.levels.slice()
                failure: id
                duration: getDuration(name)
              }
              result.failed.push item
              addtotree item
              cLine.type = "fail"
            else if name.search(/^\d+ passing/) > -1 # end test
              state.inTest = false
              result.duration = getDuration(name)
              finished() if result.failed.length == 0
            else  # level
              if currentIndent > state.indent
                state.levels.push name
              else if currentIndent == state.indent
                state.levels[state.levels.length-1] = name
              else
                removecount = (state.indent - currentIndent)/2
                state.levels.splice state.levels.length - removecount, removecount
                state.levels[state.levels.length-1] = name
              state.indent = currentIndent
              cLine.type = "level"
          else # backTrail
            if state.inError #inError
              state.error.text.push name
              state.inError++
            else if name.search(/^\d+\)/) > -1 # failed test
              id = name.match(/(^\d+)\)/)[1]
              state.error = {id: id, text:[] }
              state.inError = 1
            if state.inError == 2
              cLine.type ="error"
        else # line with no indent
          if cLine.text.search(datetimeRegex) > -1
            cLine.text = cLine.text.replace(datetimeRegex,"")
            cLine.type ="stderr"
      else # empty line
        if state.inError
          state.inError = 0
          addError()
    if not cLine.html
      console.log "creating html"
      if cLine.text
        cLine.html = sce.trustAsHtml(cLine.text.replace(/ /g,"&nbsp;"))
      else
        cLine.html = sce.trustAsHtml("<br>")
    result.console.push cLine
    console.log "progressing"
    progress()
  socket.on "consoleLine", parseLine
  socket.on "getConsole", (currentConsole) ->
    reset()
    for cLine in currentConsole
      parseLine(cLine)
  return result
