###
  lib\diff.coffee
###

{$} = require 'atom'

module.exports = 
class Diff
  
  constructor: (@diffPopup, @editorView, @editor) ->
    {@projPath, @archiveDir, @haveLiveArchive, @gitRepo,
    @fs, @PopupView, @archiveDir, @maxGitGap, @load, @save} = @diffPopup
    @filePath = @editor.getPath()
    @handleEvents()
    @toggle()
    
  toggle: ->
      if @diffView?.hasParent() then @close(); return
      @mouseIsDown = no
      range  = @editor.getLastSelection().getBufferRange()
      @noSelection = range.isEmpty()
      @initPos = [range.start.row, 0]
      @lastPos = [range.end.row+1, 0]
      @setSelectedBufferRange()
      @calcSel()
    
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
    # gitHeadText = atom.project.getRepo().repo.getHeadBlob @filePath
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
    if @gitRepo and atom.project.getRepo().isPathModified @filePath
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
    
  getPosForLineNum: (text, lineNum) ->
    lfRegex = new RegExp '\\n', 'g'
    num = lastlLastIndex = 0
    while (match = lfRegex.exec text)
      if num++ is lineNum
        return lastlLastIndex
      lastlLastIndex = lfRegex.lastIndex
    if num is lineNum
      return lastlLastIndex
    text.length
      
  getDiff: ->
    diffText = if @usingGit then @diffTextLines.join ''
    else if @haveLiveArchive
      oldText = @load.text(@projPath, @filePath, -2).text
      newText = @editor.getText()
      posIn   = [@getPosForLineNum(newText, @initPos[0]), 
                 @getPosForLineNum(newText, @lastPos[0])]
      [topPos, botPos] = @save.trackPos newText, oldText, posIn
      oldText[topPos...botPos]
    else
      "No matching git repo or Live-Archive text found."
    @diffView = new @PopupView @editorView, diffText
      
  handleEvents: ->
    @editorView.on      'mousedown', '.line', (e) => @mousedown e
    @editorView.on      'mousemove',          (e) => @mousemove e
    @editorView.on        'mouseup',          (e) => @mouseup   e
    atom.workspaceView.on 'mouseup',          (e) => @mouseup   e
    
  close: ->
    @diffView?.destroy()
    @mouseIsDown = @initPos = @lastPos = null
    
