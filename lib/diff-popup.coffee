###
 lib\diff-popup.coffee
###

{$} = require 'atom'

module.exports = 

  configDefaults:
    lineGapsAllowedInGitRegion: 3
  
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
    @rootDir         = atom.project.getRootDirectory().path
    @archiveDir      = @rootDir + '/.live-archive'
    @haveLiveArchive = @fs.existsSync @archiveDir
    @haveGitRepo     = (@repo = atom.project.getRepo())?
    
    console.log 'delayedActivate', {@haveGitRepo, @haveLiveArchive}
    
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
    line = @lineFromPageY e.pageY
    @initPos = [line,   0] 
    @lastPos = [line+1, 0]
    @setSelectedBufferRange()
  
  mousemove: (e) ->
    if not @mouseIsDown then return
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
    # @editor.setSelectedBufferRange @chkOrder()
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
    console.log 'haveSelLines', {top, bot}
    
    
  handleEvents: ->
    @editorView.on      'mousedown', '.line', (e) => @mousedown e
    @editorView.on      'mousemove',          (e) => @mousemove e
    @editorView.on        'mouseup',          (e) => @mouseup   e
    atom.workspaceView.on 'mouseup',          (e) => @mouseup   e
    
  close: ->
    @diffView?.destroy()
    @mouseIsDown = @initPos = @lastPos = null
    
