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
      range  = @editor.getLastSelection().getBufferRange()
      range  = [[range.start.row, 0], [range.end.row + 1, 0]]
      @editor.setSelectedBufferRange range
      @haveRange range
    
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
    
  selLines: (topY, botY) ->

  mousedown: (e) ->
    if @trackingMouse or not e.altKey or not e.ctrlKey
      @trackingMouse = no
      return
    line = @lineFromPageY e.pageY
    @initPos = [line,   0] 
    @lastPos = [line+1, 0]
    @editor.setSelectedBufferRange [@initPos, @lastPos]
    @mouseIsDown = yes
    console.log 'mousedown'
  
  mousemove: (e) ->
    if not @mouseIsDown then return
    @lastPos = [@lineFromPageY(e.pageY)+1, 0]
    @editor.setSelectedBufferRange [@initPos, @lastPos]
    @trackingMouse = yes
    console.log 'mouseup'
  
  mouseup: (e) ->
    if not @mouseIsDown then return
    console.log 'mouseup'
    line = @lineFromPageY e.pageY
    @lastPos = [line+1, 0]
    @editor.setSelectedBufferRange [@initPos, @lastPos]
    @haveRange [@initPos, @lastPos]
    @trackingMouse = @mouseIsDown = no
    
  haveRange: (range) ->
    console.log 'haveRange', range
  
  handleEvents: ->
    @editorView.on      'mousedown', '.line', (e) => @mousedown e
    @editorView.on      'mousemove',          (e) => @mousemove e
    @editorView.on        'mouseup',          (e) => @mouseup   e
    atom.workspaceView.on 'mouseup',          (e) => @mouseup   e
    
  close: ->
    @diffView?.destroy()
    @mouseIsDown = @trackingMouse =
    @initPageX   = @initPageY =
    @lastPageX   = @lastPageY = null
