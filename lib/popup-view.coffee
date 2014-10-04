{$, View} = require 'atom'

module.exports =
class PopupView extends View
  @content: ->
    @div class:'overlay from-top diff-popup native-key-bindings', tabindex: -1, draggable:no, =>
      @div outlet:'toolBar', class:'diff-popup-toolbar', draggable:no, =>
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div outlet: 'btns', class: 'btns', =>
          @span class:'btn icon-left-open'
          @span class:'btn icon-git'
          @span class:'btn icon-right-open'
          @span class:'btn icon-reply'
          @span class:'btn icon-docs'
          @span class:'btn icon-cancel'
        
      @div outlet:'textOuter', class: 'diff-text-outer editor-colors', =>
        @pre outlet:'diffText', class: 'diff-text editor-colors', =>

  initialize: (@diff, diffText) ->
    @diffText.text diffText
    @appendTo atom.workspaceView
    process.nextTick => @setViewPosDim()
    
    @subscribe @toolBar, 'mousedown', (e) =>
      pos = @offset()
      @initLeft = pos.left; @initTop = pos.top
      @initPageX = e.pageX; @initPageY = e.pageY
      @dragging = yes
      console.log 'mousedown', e.which, @dragging
      false
      
    @subscribe atom.workspaceView, 'mousemove', (e) =>
      if @dragging
        if e.which is 0 
          @dragging = no
          console.log 'mousemove', e.which, @dragging
          return
        left = @initLeft + (e.pageX - @initPageX)
        top  = @initTop  + (e.pageY - @initPageY)
        @css {left, top, right: 'auto', bottom: 'auto'}
        false
      
    @subscribe @toolBar, 'mouseup',           (e) => 
      @dragging = no
      console.log '@toolBar mouseup', e.which, @dragging
      
    @subscribe atom.workspaceView, 'mouseup', (e) => 
      @dragging = no
      console.log 'workspaceView mouseup', e.which, @dragging
    
    @subscribe @btns, 'click', (e) =>
      classes = $(e.target).attr 'class'
      switch classes[9...]
        when 'left-open'  then @diff.close()
        when 'git'        then @diff.close()
        when 'right-open' then @diff.close()
        when 'reply'      then @diff.revert diffText;         @diff.close()
        when 'docs'       then atom.clipboard.write diffText; @diff.close()
        when 'cancel'     then                                @diff.close()
        
    @subscribe atom.workspaceView, 'keydown', (e) => 
      if e.which is 27 then @diff.close() 
  
  setViewPosDim: ->
    $win = $ window
    wW = $win.width()
    wH = $win.height()
    pW = Math.max 280, Math.min wW/2, @textOuter.width()
    pH = Math.max  40, Math.min wH/2, @textOuter.height()
    [width, height, left, top, right, bottom] = [pW, pH, 'auto', 40, 30, 'auto']
    
    {left:dL, top:dT, right:dR, bottom:dB} = @diff.getDiffBox()
    umW = dR - dL
    urW = wW - dR
    if pW < umW + urW and pH < dT
      [left, top, right, bottom] = [dL, (dT-pH)/2, 'auto', 'auto']
      
    @textOuter.css {width, height}
    @css {left, top, right, bottom, visibility: 'visible'}
  
          
  destroy: ->
    atom.workspaceView.find('.dif-pop-marker').removeClass 'dif-pop-marker'
    @detach()
    @unsubscribe()
    atom.workspaceView.find('.editor:visible').focus()
    