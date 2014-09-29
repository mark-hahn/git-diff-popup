###
    lib\diff-popup.coffee
    line 2
###

{$} = require 'atom'

module.exports = 

  configDefaults:
    maximumLinesInGitGap: 3
  
  activeMousedown: (e) =>
    if e.altKey and e.ctrlKey
      if not @delayActivated then @delayedActivate()
      @mousedown e

  activate: ->
    @$itemViews = atom.workspaceView.find '.item-views'
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
      @calcSel()
    
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
    @calcSel()
    
  chkOrder: ->
    if @initPos[0] < @lastPos[0]
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
  
  getGitHeadTextLines: ->
    bufText = @editor.getText()
    chkoutOk = yes
    try
      chkoutOk = @gitRepo.checkoutHead @filePath
      gitHeadText = @fs.readFileSync(@filePath).toString()
    catch e
      chkoutOk = no
    @fs.writeFileSync @filePath, bufText
    if not chkoutOk then return no
    lines = []
    lastLastIndex = 0
    lfRegex = new RegExp '\\n', 'g'
    @gitHeadTextLines = []
    while (match = lfRegex.exec gitHeadText) 
      @gitHeadTextLines.push gitHeadText[lastLastIndex...lfRegex.lastIndex]
      lastLastIndex = lfRegex.lastIndex
    console.log 'getGitHeadTextLines', @gitHeadTextLines.length
    true
    
  addDiffText: (diffLineNums, after = yes) ->
    strt = diffLineNums.oldStart-1
    end  = strt + diffLineNums.oldLines
    lines = @gitHeadTextLines[strt...end]
    if after
      @diffTextLines = @diffTextLines.concat lines
    else
      @diffTextLines = lines.concat @diffTextLines
    console.log 'addDiffText', {strt, end, lines}
      
  calcSel: ->
    [[top, nil], [bot, nil]] = @chkOrder()
    @usingGit = no
    @diffTextLines = []
    if @gitRepo and @gitRepo.isPathModified @filePath
      gitRegionStart = null
      gitDiffs = @gitRepo.getLineDiffs @filePath, @editor.getText()
      for gitDiff, centerDiffIdx in gitDiffs
        gitRegionStart = gitDiff.newStart - 1
        gitRegionEnd   = gitRegionStart + gitDiff.newLines
        gitMatch = (gitRegionStart <= top < gitRegionEnd)
        if gitMatch and @getGitHeadTextLines()
          @addDiffText gitDiff
          diffIdx = centerDiffIdx
          while (gitDiffBefore = gitDiffs[--diffIdx])
            gitBot = gitDiffBefore.newStart - 1 + gitDiffBefore.newLines + @maxGitGap
            if gitBot >= gitRegionStart 
              @addDiffText gitDiffBefore, no
              gitRegionStart = gitDiffBefore.newStart - 1
            else break
          diffIdx = centerDiffIdx
          while (gitDiffAfter = gitDiffs[++diffIdx])
            gitTop = gitDiffAfter.newStart - 1 - @maxGitGap
            if gitTop <= gitRegionEnd 
              @addDiffText gitDiffAfter
              gitRegionEnd = gitDiffAfter.newStart - 1 + gitDiffAfter.newLines
            else break
          break
      if gitRegionStart? and (@usingGit = (gitRegionStart <= @initPos[0] <  gitRegionEnd and
                                           gitRegionStart <  @lastPos[0] <= gitRegionEnd))
          @initPos = [gitRegionStart, 0]
          @lastPos = [gitRegionEnd,   0]
    @setSelectedBufferRange()
    @getDiff()
    console.log 'calcSel', @usingGit, {@initPos, @lastPos, @diffTextLines}
    
  getDiff: ->
    newText = @editor.getText()
    diffText = if @usingGit then @diffTextLines.join ''
    else if @haveLiveArchive
      @load.text(@projPath, @filePath, -2).text
    else
      "No matching git repo or Live-Archive text found."
      
    console.log 'getDiff', @usingGit, diffText
      
  handleEvents: ->
    @editorView.on      'mousedown', '.line', (e) => @mousedown e
    @editorView.on      'mousemove',          (e) => @mousemove e
    @editorView.on        'mouseup',          (e) => @mouseup   e
    atom.workspaceView.on 'mouseup',          (e) => @mouseup   e
    
  close: ->
    @diffView?.destroy()
    @mouseIsDown = @initPos = @lastPos = null
    
