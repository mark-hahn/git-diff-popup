###
  lib\diff.coffee
###

{$} = require 'atom'

module.exports = 
class Diff
  test1: ->
  constructor: (@diffPopup) ->
    {@projPath, @archiveDir, @haveLiveArchive, @gitRepo} = @diffPopup
    
    @editorView = atom.workspaceView.getActiveView()
    if not (@editor = @editorView?.getEditor?())
      return
    @filePath = @editor.getPath()
    
    @fs           = require 'fs'
    @PopupView    = require './popup-view'
    @archiveDir   = @projPath + '/.live-archive'
    @maxGitGap    = atom.config.get 'git-diff-popup.maximumLinesInGitGap'
    {@load,@save} = require 'text-archive-engine'
    range         = @editor.getLastSelection().getBufferRange()
    @emptySel     = range.isEmpty()
    @topSelRow    = range.start.row
    @botSelRow    = range.end.row + 1
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
      for gitDiff in gitDiffs
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
        text = headText[@lineNumPos(headText, @gitSelOldTop) ... @lineNumPos(headText, @gitSelOldBot)]
        @diffView = new @PopupView @, text, 0
        @setSelection()
        return
    @setSelection()
    if not @haveLiveArchive
      atom.confirm
        message: '--- git-diff-popup Error ---\n\n'
        detailedMessage: "The selection does not overlap a git difference."
        buttons: OK: -> 
      return
    @nextLA -1
    
  getLAText: (vers) ->
    newText   = @editor.getText()
    laText    = @load.text(@projPath, @filePath, vers).text
    topSelPos = @lineNumPos newText, @topSelRow
    botSelPos = @lineNumPos newText, @botSelRow
    [topPos, botPos] = @save.trackPos newText, laText, [topSelPos, botSelPos]
    laText[topPos ... botPos]

  showDiffView: (txt, vers) ->
    if not @diffView then @diffView = new @PopupView @, txt, vers
    else @diffView.setText txt, vers

  nextLA: (delta) ->
    startVers = @lastLAVers ? -1
    while not (delta is +1 and @lastLAVers is -1 or delta is -1 and @lastLAText is '')
      @lastLAVers =  (if not @lastLAVers? then -1 else @lastLAVers + delta)
      text = @getLAText @lastLAVers
      if text is '' or text not in [@editor.getSelectedText(), @lastLAText]
        @showDiffView (@lastLAText = text), @lastLAVers
        return
      if (timedOut = (@lastLAVers % 10 is 0)) then break
    @showDiffView """
      --- No Difference Found ---
      No difference was found in the selection from version #{-startVers} to version #{-@lastLAVers}.
      #{if timedOut then 'Use the left arrow to try older versions.' else ''}
    """, @lastLAVers, yes
    @lastLAText = null
    
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
    selText = @editor.getSelectedText()
    if atom.workspaceView.getActiveView()?.getEditor?() isnt @editor or selText isnt @originalSelText
      atom.confirm
        message: '--- git-diff-popup Error ---\n\n'
        detailedMessage: 'The text to be reverted has been modified. Please re-open the popup and try again.'
        buttons: OK: -> 
      return
    @editor.insertText text
      
  close: ->
    @diffView?.destroy()
    @diffPopup.diffClosed()
