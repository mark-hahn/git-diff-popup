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
    @topSelRow   = range.start.row
    @botSelRow   = range.end.row + 1
    @getSelection()

  getGitHeadText: ->
    # gitHeadText = atom.project.getRepo().repo.getHeadBlob @filePath
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
      
  getSelection: ->
    if @gitRepo and atom.project.getRepo().isPathModified @filePath
      gitDiffs = @gitRepo.getLineDiffs @filePath, @editor.getText()
      for gitDiff, centerDiffIdx in gitDiffs
        gitChunkNewTop = gitDiff.newStart - 1
        gitChunkNewBot = gitChunkNewTop + gitDiff.newLines
        if not (gitChunkNewTop > @botSelRow or gitChunkNewBot < @topSelRow) 
          @gitSelOldTop ?= gitDiff.oldStart - 1
          @gitSelOldBot  = gitDiff.oldStart - 1 + gitDiff.oldLines
          @gitSelNewTop ?= gitChunkNewTop
          @gitSelNewBot  = gitChunkNewBot
    if (@usingGit = @gitSelNewTop?)
      @topSelRow = Math.min @topSelRow, @gitSelNewTop
      @botSelRow = Math.max @botSelRow, @gitSelNewBot
      @gitSelOldTop -= (@gitSelNewTop - @topSelRow)
      @gitSelOldBot += (@botSelRow - @gitSelNewBot)
      
    @editor.setSelectedBufferRange [[@topSelRow, 0], [@botSelRow, 0]]
    @originalSelText = @editor.getSelectedText()
    
    diffText = (
      if @usingGit 
        headText = @getGitHeadText()
        headText[@lineNumPos(headText, @gitSelOldTop) ... @lineNumPos(headText, @gitSelOldBot)]
      else if @haveLiveArchive
        oldText = @load.text(@projPath, @filePath, -2).text
        newText = @editor.getText()
        posIn   = [@lineNumPos(newText, @topSelRow), 
                   @lineNumPos(newText, @botSelRow)]
        [topPos, botPos] = @save.trackPos newText, oldText, posIn
        oldText[topPos ... botPos]
      else
        "No earlier version of the selected text was found in the repository head."
    )
    @diffView = new @PopupView @, diffText
    
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
    if @originalSelText isnt @editor.getSelectedText()
      atom.confirm
        message: '--- Diff-Popup Error ---\n\n'
        detailedMessage: 'The text to be reverted has been modified. Please re-open the popup and try again.'
        buttons: OK: -> return
    @editor.insertText text
      
  close: ->
    @diffView?.destroy()
    @diffPopup.diffClosed()
