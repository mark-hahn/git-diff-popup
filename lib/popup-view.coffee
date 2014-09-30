{View} = require 'atom'

module.exports =
class PopupView extends View
  @content: ->
    @div class:'overlay from-top diff-popup', tabindex: -1, =>
      @div class:'diff-popup-toolbar', =>
        @span class:'diff-popup-collapse'
        @span class:'diff-popup-close'
        
        # unfold  
        
      @div class: 'diff-text-outer editor-colors', =>
        @pre outlet:'diffText', class: 'diff-text', =>
          
  initialize: (editorView, diffText) ->
    console.log 'PopupView initialize', diffText
    @diffText.text(diffText) # .css fontSize: Math.floor editorView.lineHeight * 0.6
    @appendTo atom.workspaceView
    
    atom.workspaceView.keydown (e) => 
      if e.which is 27 then @destroy() 
    
  destroy: ->
    @detach()

