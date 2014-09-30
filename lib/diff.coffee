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
      console.log 'diff-popup: no editor in this tab'
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
    @setSelectedBufferRange()
    @calcSel()
    
  setSelectedBufferRange: ->
    $lineNums = @editorView.find '.gutter .line-number'
    $lineNums.find('.icon-right').removeClass 'diff-pop-hilite'
    top = $lineNums.index $lineNums.filter \
  	       '[data-buffer-row="' + @topSelRow + '"]'
    bot = $lineNums.index $lineNums.filter \
           '[data-buffer-row="' + @botSelRow + '"]'
    $lineNums.slice top, bot
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
    @usingGit = no
    @diffTextLines = []
    if @gitRepo and atom.project.getRepo().isPathModified @filePath
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
      if gitRegionStart? and (@usingGit = (gitRegionStart <= @topSelRow <  gitRegionEnd and
                                           gitRegionStart <  @botSelRow <= gitRegionEnd))
          @topSelRow = gitRegionStart
          @botSelRow = gitRegionEnd
    @setSelectedBufferRange()
    @getDiff()
    console.log 'calcSel', @usingGit, {@topSelRow, @botSelRow, @diffTextLines}
    
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
    @diffView = new @PopupView @editorView, diffText
      
  close: ->
    @diffView?.destroy()
    @mouseIsDown = @topSelRow = @botSelRow = null
    
