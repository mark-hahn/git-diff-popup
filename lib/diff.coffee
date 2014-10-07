###
  lib\diff.coffee
###

{$} = require 'atom'

module.exports = 
class Diff
  
  constructor: (@diffPopup) ->
    {@projPath, @archiveDir, @haveLiveArchive, @gitRepo} = @diffPopup
    
    @editorView = atom.workspaceView.getActiveView()
    if not (@editor = @editorView?.getEditor?())
      # console.log 'diff-popup: no editor in this tab'
      return
    @filePath = @editor.getPath()
    
    @fs           = require 'fs'
    @PopupView    = require './popup-view'
    @archiveDir   = @projPath + '/.live-archive'
    @maxGitGap    = atom.config.get 'diff-popup.maximumLinesInGitGap'
    {@load,@save} = require 'text-archive-engine'
    
    range        = @editor.getLastSelection().getBufferRange()
    @emptySel    = range.isEmpty()
    @topSelRow   = range.start.row
    @botSelRow   = range.end.row + 1
    @getSelection()

  getGitHeadText: ->
    bufText = @editor.getText()
    chkoutOk = yes
    try
      chkoutOk = @gitRepo.checkoutHead @filePath
      gitHeadText = @fs.readFileSync(@filePath).toString()
    catch e
      chkoutOk = no
    @fs.writeFileSync @filePath, bufText
    if chkoutOk then return gitHeadText
    
  lineNumPos: (text, lineNum) ->
    lfRegex = new RegExp '\\n', 'g'
    num = lastlLastIndex = 0
    while (match = lfRegex.exec text)
      if num++ is lineNum
        return lastlLastIndex
      lastlLastIndex = lfRegex.lastIndex
    if num is lineNum
      return lastlLastIndex
    text.length
    
  setSelection: ->
    @editor.setSelectedBufferRange [[@topSelRow, 0], [@botSelRow, 0]]
    @originalSelText = @editor.getSelectedText()
    
  getSelection: ->
    if @gitRepo and atom.project.getRepo().isPathModified @filePath
      gitDiffs = @gitRepo.getLineDiffs @filePath, @editor.getText()
      for gitDiff, centerDiffIdx in gitDiffs
        if gitDiff.newLines is 0 then gitDiff.newStart++
        gitChunkNewTop = gitDiff.newStart - 1
        gitChunkNewBot = gitChunkNewTop + gitDiff.newLines
        if not (gitChunkNewTop > @botSelRow or gitChunkNewBot < @topSelRow)
          @gitSelNewTop ?= gitChunkNewTop
          @gitSelNewBot  = gitChunkNewBot
          @gitSelOldTop ?= gitDiff.oldStart - 1
          @gitSelOldBot  = gitDiff.oldStart - 1 + gitDiff.oldLines
      if (@usingGit = @gitSelNewTop? and (@emptySel or not @haveLiveArchive))
        @topSelRow = Math.min @topSelRow, @gitSelNewTop
        @botSelRow = Math.max @botSelRow, @gitSelNewBot
        @gitSelOldTop -= (@gitSelNewTop - @topSelRow)
        @gitSelOldBot += (@botSelRow - @gitSelNewBot)
        headText = @getGitHeadText()
        @gitText = 
          headText[@lineNumPos(headText, @gitSelOldTop) ... @lineNumPos(headText, @gitSelOldBot)]
        @diffView = new @PopupView @, @gitText, yes
        @setSelection()
        return
    @setSelection()
    if not @haveLiveArchive
      atom.confirm
        message: '--- Diff-Popup Error ---\n\n'
        detailedMessage: "The selection does not overlap a git difference."
        buttons: OK: -> 
      return
    @nextLA -1
      
  getLAText: (vers) ->
    laText  = @load.text(@projPath, @filePath, vers).text
    newText = @editor.getText()
    posIn   = [@lineNumPos(newText, @topSelRow), 
               @lineNumPos(newText, @botSelRow)]
    [topPos, botPos] = @save.trackPos newText, laText, posIn
    laText = laText[topPos ... botPos]
    @diffView ?= new @PopupView @, laText, no
    laText
    
  nextLA: (delta) ->
    if not @laVersionNum then @laText = @getLAText(@laVersionNum = -1)
    laText = @laText
    loop 
      if (delta is 1 and @laVersionNum is -1 or delta is -1 and @laText is '') or
         (laText = @getLAText(@laVersionNum += delta)) isnt @laText then break
    @diffView.setText (@laText = laText)
    
  getDiffBox: ->
    sbr = @editor.getSelectedBufferRange()
    frstRow     = sbr.start.row
    lastRow     = sbr.end.row
    $scrollView = @editorView.find '.scroll-view'
    {left:svLft, top:svTop} = $scrollView.offset() 
    svRgt       = svLft + $scrollView.width()
    svBot       = svTop + $scrollView.height()
    $line       = @editorView.find '.line[data-screen-row="' + frstRow + '"]'
    {left, top} = $line.offset()
    right       = left + $line.width()
    bottom      = top + (lastRow - frstRow) * $line.height()
    left        = Math.max svLft, left
    top         = Math.max svTop, top
    right       = Math.min svRgt, right
    bottom      = Math.min svBot, bottom
    {left, top, right, bottom}
    
  revert: (text) -> 
    if atom.workspaceView.getActiveView()?.getEditor?() isnt @editor or
    	   @originalSelText isnt @editor.getSelectedText()
      atom.confirm
        message: '--- Diff-Popup Error ---\n\n'
        detailedMessage: 'The text to be reverted has been modified. Please re-open the popup and try again.'
        buttons: OK: -> 
      return
    @editor.insertText text
      
  close: ->
    @diffView?.destroy()
    @diffPopup.diffClosed()
