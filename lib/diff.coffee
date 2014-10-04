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
    @noSelection = range.isEmpty()
    @topSelRow   = range.start.row
    @botSelRow   = range.end.row + 1
    @expandGitSelection()
    @addHilitesToSelection()

  addHilitesToSelection: ->
    $lineNums = @editorView.find '.gutter .line-number'
    $lineNums.find('.icon-right').removeClass 'dif-pop-marker'
    for lineNum in [@topSelRow...@botSelRow]
      $lineNums.filter('[data-buffer-row="' + lineNum + '"]').find('.icon-right').addClass 'dif-pop-marker'
    null
      
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
    # console.log 'getGitHeadTextLines', @gitHeadTextLines.length
    true
    
  addDiffText: (diffLineNums, after = yes) ->
    strt = diffLineNums.oldStart-1
    end  = strt + diffLineNums.oldLines
    lines = @gitHeadTextLines[strt...end]
    if after
      @diffTextLines = @diffTextLines.concat lines
    else
      @diffTextLines = lines.concat @diffTextLines
    # console.log 'addDiffText', {strt, end, lines}
      
  expandGitSelection: ->
    @usingGit = no
    @diffTextLines = []
    if @noSelection and @gitRepo and atom.project.getRepo().isPathModified @filePath
      gitRegionStart = null
      gitDiffs = @gitRepo.getLineDiffs @filePath, @editor.getText()
      for gitDiff, centerDiffIdx in gitDiffs
        gitRegionStart = gitDiff.newStart - 1
        gitRegionEnd   = gitRegionStart + gitDiff.newLines
        gitMatch = (gitRegionStart <= @topSelRow < gitRegionEnd)
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
      if (@usingGit = gitRegionStart?)
          @topSelRow = gitRegionStart
          @botSelRow = gitRegionEnd
    @addHilitesToSelection()
    @getDiff()
    # console.log 'expandGitSelection', @usingGit, {@topSelRow, @botSelRow, @diffTextLines}
    
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
      posIn   = [@getPosForLineNum(newText, @topSelRow), 
                 @getPosForLineNum(newText, @botSelRow)]
      [topPos, botPos] = @save.trackPos newText, oldText, posIn
      oldText[topPos...botPos]
    else
      "No matching git repo or Live-Archive text found."
    @diffView = new @PopupView @, diffText
    
  findDiff: ->
    if ($diffHilites = atom.workspaceView.find '.dif-pop-marker').length > 0 and
       (editorView = $diffHilites.eq(0).closest('.editor').view()).is(':visible') and
       (textEditor = editorView.getModel())
          rowNum = null
          $diffHilites.each ->
            diffRowNum = +$(@).closest('.line-number').attr 'data-screen-row'
            rowNum ?= diffRowNum
            if rowNum++ isnt diffRowNum then rowNum = 'err'; return false
          if rowNum is 'err' then return {}
          frstRow = $diffHilites.first().closest('.line-number').attr('data-screen-row') - 1
          lastRow = $diffHilites.last() .closest('.line-number').attr('data-screen-row') - 1
          {editorView, textEditor, frstRow, lastRow}
    else {}
    
  getDiffBox: ->
    {editorView, frstRow, lastRow} = @findDiff()
    $scrollView = editorView.find '.scroll-view'
    {left:svLft, top:svTop} = $scrollView.offset() 
    svRgt       = svLft + $scrollView.width()
    svBot       = svTop + $scrollView.height()
    $line       = editorView.find '.line[data-screen-row="' + (frstRow+1) + '"]'
    {left, top} = $line.offset()
    right       = left + $line.width()
    bottom      = top  + (lastRow - frstRow + 1) * $line.height()
    left        = Math.max svLft, left
    top         = Math.max svTop, top
    right       = Math.min svRgt, right
    bottom      = Math.min svBot, bottom
    {left, top, right, bottom}
    
  revert: (text) -> 
    {textEditor, frstRow, lastRow} = @findDiff()
    if textEditor
      firstVis = textEditor.getFirstVisibleScreen()
      lastVis  = textEditor.getLastVisibleScreen() 
      if not (lastRow < firstVis or frstRow > lastVis)  
        textEditor.setTextInBufferRange [[frstRow, 0], [lastRow+1, 0]], text
        return
    atom.confirm
      message: '--- Diff-Popup Error ---\n\n'
      detailedMessage: 'Unable to revert text. ' +
    	                 'The difference text is not contiguous or not visible in the tab.'
      buttons: OK: -> return
      
  close: ->
    @diffView?.destroy()
    @diffPopup.diffClosed()
