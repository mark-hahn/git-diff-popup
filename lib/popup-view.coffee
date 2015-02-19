{$, View} = require 'atom'

module.exports =
class PopupView extends View
  @content: ->
    @div class:'overlay from-top git-diff-popup native-key-bindings', tabindex: -1, =>
      @div outlet:'toolBar', class:'git-diff-popup-toolbar', draggable:no, =>
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div class:'drag-bkgd', draggable:no
        @div outlet: 'btns', class: 'btns', =>
          @span class:'show-git icon-git'
          @span outlet:'laVersion', class:'show-ver show-msg la-version'
          @span class:'btn show-ver show-msg icon-left-open'
          @span class:'btn show-ver show-msg icon-right-open'
          @span class:'btn show-git show-ver icon-reply'
          @span class:'btn show-git show-ver icon-docs'
          @span class:'btn show-git show-ver show-msg icon-cancel'
        
      @div outlet:'textOuter', class: 'diff-text-outer editor-colors', =>
        @pre outlet:'diffText', class: 'diff-text editor-colors', =>

  initialize: (@diff, diffText, @version, @showMsg) ->
    @diffText.text diffText
    @appendTo atom.workspaceView
    process.nextTick => @setViewPosDim()
    
    @subscribe @, 'mousedown', (e) =>
      pos = @offset()
      @initLeft = pos.left; @initTop = pos.top
      @initPageX = e.pageX; @initPageY = e.pageY
      if @initPageY > @initTop + 20 then return
      @dragging = yes
      false
      
    @subscribe atom.workspaceView, 'mousemove', (e) =>
      if @dragging
        if e.which is 0 
          @dragging = no
          return
        left = @initLeft + (e.pageX - @initPageX)
        top  = @initTop  + (e.pageY - @initPageY)
        @css {left, top, right: 'auto', bottom: 'auto'}
        false
      
    @subscribe @toolBar, 'mouseup',           (e) => 
      @dragging = no
      
    @subscribe atom.workspaceView, 'mouseup', (e) => 
      @dragging = no
    
    @subscribe @btns, 'click', (e) =>
      classes = $(e.target).attr 'class'
      iconIdx = classes.indexOf 'icon-'
      switch classes[iconIdx+5...]
        when 'left-open'  then @diff.nextLA -1
        when 'right-open' then @diff.nextLA +1
        when 'reply'      then @diff.revert         @diffText.text(); @diff.close()
        when 'docs'       then atom.clipboard.write @diffText.text(); @diff.close()
        when 'cancel'     then                                        @diff.close()
        
    @subscribe atom.workspaceView, 'keydown', (e) => 
      if e.which is 27 then @diff.close() 
      
  setViewPosDim: ->
    # @css {top:0, left:0, visibility: 'visible'}
    # return
    $win   = $ window
    wW     = $win.width()
    wH     = $win.height()
    tW     = @textOuter.width()
    tH     = @textOuter.height()
    width  = Math.max 270, Math.min wW/2,  tW
    height = Math.max  40, Math.min wH-40, tH
    # @textOuter.css {width, height}
    
    pW = width  + @width()  - tW + 22
    pH = height + @height() - tH + 21 
    
    {left:dL, top:dT, right:dR, bottom:dB} = @diff.getDiffBox()
    dW = dR-dL
    rW = wW-dR
    if pW < dW+rW and pH < dT - 10
      [left, top, right, bottom] = [dL+10,  dT-pH-10, 'auto', 'auto']
    else if pW < dW+rW and pH < wH-dB
      [left, top, right, bottom] = [dL+10,  dB+10, 'auto', 'auto']
    else if pH < dT
      [left, top, right, bottom] = ['auto', dT-pH-10, 20, 'auto']
    else if pH < wH-dB
      [left, top, right, bottom] = ['auto', dB+10, 20, 'auto']
    else if pW < wW-40
      [left, top, right, bottom] = ['auto', 20, 20, 'auto']
    else if pW < dL
      [left, top, right, bottom] = [20, 20, 'auto', 'auto']
    @css {left, top, right, bottom, visibility: 'visible'}
    
    @laVersion.text 'v' + -@version
    @btns.children().css display: 'none'
    switch
      when @showMsg      then @.find('.show-msg').css display: 'inline-block'
      when @version is 0 then @.find('.show-git').css display: 'inline-block'
      else                    @.find('.show-ver').css display: 'inline-block'
        
  setText: (diffText, @version, @showMsg) ->
    @diffText.text diffText
    @css
      visibility: 'hidden'
      top: 				'auto'
      right:      'auto'
      bottom:     'auto'
      left: 			'auto'
    @textOuter.css width: 'auto', height: 'auto'
    process.nextTick => @setViewPosDim()
  
  destroy: ->
    @destroyed = yes
    @detach()
    @unsubscribe()
    atom.workspaceView.find('.editor:visible').focus()
