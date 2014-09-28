### 2
 lib\diff-popup.coffee
###

{$} = require 'atom'

module.exports = 

  configDefaults:
    maximumLinesInGitGap: 3
  
  activate: ->
    @$itemViews = atom.workspaceView.find '.item-views'
    
    @activeMousedown = (e) =>
      if e.altKey and e.ctrlKey
        if not @delayActivated then @delayedActivate()
        @mousedown e

    @$itemViews.on 'mousedown', '.editor .line', (e) => @activeMousedown e
      
    atom.workspaceView.command "diff-popup:toggle", => 
      if not @delayActivated then @delayedActivate()
      if @diffView?.hasParent() then @close(); return
      @mouseIsDown = no
      range  = @editor.getLastSelection().getBufferRange()
      @noSelection = range.isEmpty()
      @initPos = [range.start.row, 0]
      @lastPos = [range.end.row+1, 0]
      @setSelectedBufferRange()
      @haveSelLines()
    
  delayedActivate: ->
    @fs       = require 'fs'
    @pathUtil = require 'path'
    {@load}   = require 'text-archive-engine'
    
    @editorView      = atom.workspaceView.getActiveView()
    @editor          = @editorView.getModel()
    @filePath        = @editor.getPath()
    @projPath        = atom.project.getRootDirectory().path
    @archiveDir      = @projPath + '/.live-archive'
    @haveLiveArchive = @fs.existsSync @archiveDir
    @gitRepo         = atom.project.getRepo()
    @maxGitGap       = atom.config.get 'diff-popup.maximumLinesInGitGap'
    
    console.log 'delayedActivate', {@gitRepo, @haveLiveArchive}
    
    if not @haveGitRepo and not @haveLiveArchive
        atom.confirm
          message: '--- Diff-Popup Error ---\n\n'
          detailedMessage: 'You must have either a Git repo or the Live-Archive ' +
                           'package to use the diff-popup package.'
          buttons: OK: -> return
    
    @$itemViews.off 'mousedown', @activeMousedown
    @handleEvents()
    @delayActivated = yes
    
  lineFromPageY: (pageY) ->
    ofs = @editorView.scrollView.offset()
    top = pageY - ofs.top + @editorView.scrollTop()
    row = Math.floor  top / @editorView.lineHeight
    @editor.bufferPositionForScreenPosition([row, 0]).row
    
  mousedown: (e) ->
    if not e.altKey or not e.ctrlKey then @mouseIsDown = no; return
    if @diffView?.hasParent() then @close(); return
    @mouseIsDown = yes
    @noSelection = yes
    line = @lineFromPageY e.pageY
    @initPos = [line,   0] 
    @lastPos = [line+1, 0]
    @setSelectedBufferRange()
  
  mousemove: (e) ->
    if not @mouseIsDown then return
    @noSelection = no
    @lastPos = [@lineFromPageY(e.pageY)+1, 0]
    @setSelectedBufferRange()
  
  mouseup: (e) ->
    if not @mouseIsDown then return
    @mouseIsDown = no
    line = @lineFromPageY(e.pageY) + 1
    @lastPos = [line, 0]
    @setSelectedBufferRange()
    @haveSelLines()
    
  chkOrder: ->
    if @initPos[0] <= @lastPos[0] - 1
      [@initPos, @lastPos]
    else
      [[@lastPos[0]-1,0], [@initPos[0]+1, 0]]
        
  setSelectedBufferRange: ->
    range = @chkOrder()
    $lineNum = @editorView.find '.gutter .line-number'
    $lineNum.find('.icon-right').removeClass 'diff-pop-hilite'
    top = $lineNum.index $lineNum.filter \
  	       '[data-buffer-row="' + range[0][0] + '"]'
    bot = $lineNum.index $lineNum.filter \
          '[data-buffer-row="' + range[1][0] + '"]'
    $lineNum.slice top, bot
            .find '.icon-right'
            .addClass 'diff-pop-hilite'
  
  haveSelLines: ->
    [[top, nil], [bot, nil]] = @chkOrder()
    usingGit = no
    if @gitRepo and @gitRepo.isPathModified @filePath
      gitStrt = null
      gitDiffs = @gitRepo.getLineDiffs @filePath, @editor.getText()
      for gitDiff, centerDiffIdx in gitDiffs
        gitStrt  = gitDiff.newStart
        gitEnd   = gitStrt + gitDiff.newLines
        gitMatch = (gitStrt - @maxGitGap <= top < gitEnd + @maxGitGap)
        if gitMatch
          diffIdx = centerDiffIdx
          while (gitDiffBefore = gitDiffs[--diffIdx])
            gitBot = gitDiffBefore.newStart + gitDiffBefore.newLines
            gitBot = Math.max gitBot - @maxGitGap, 0
            if gitBot >= gitStrt then gitStrt = gitDiffBefore.newStart
            else break
          diffIdx = centerDiffIdx
          while (gitDiffAfter = gitDiffs[++diffIdx])
            gitBeg = Math.min gitDiffAfter.newStart + @maxGitGap, gitDiffs.length - 1
            if gitBeg < gitEnd then gitEnd = gitDiffAfter.newStart + gitDiffAfter.newLines
            else break
          break
      if gitStrt and (usingGit = (gitStrt <= @initPos[0] <= gitEnd and
                                  gitStrt <= @lastPos[0] <= gitEnd))
          @initPos = [gitStrt-1, 0]
          @lastPos = [gitEnd-1,  0]
    @setSelectedBufferRange()
    newText = @editor.getText()
    oldText = if usingGit
      fileText = @fs.readFileSync @filePath
      @gitRepo.checkoutHead @filePath
      gitHeadText = @fs.readFileSync @filePath
      @fs.writeFileSync @filePath, fileText
      gitHeadText.toString()
    else if @haveLiveArchive
      @load.text(@projPath, @filePath, -2).text
    else
      "No matching git repo or Live-Archive text found."
      
    console.log 'haveSelLines', usingGit, {@initPos, @lastPos, newText, oldText}
      
  handleEvents: ->
    @editorView.on      'mousedown', '.line', (e) => @mousedown e
    @editorView.on      'mousemove',          (e) => @mousemove e
    @editorView.on        'mouseup',          (e) => @mouseup   e
    atom.workspaceView.on 'mouseup',          (e) => @mouseup   e
    
  close: ->
    @diffView?.destroy()
    @mouseIsDown = @initPos = @lastPos = null
    
