{View} = require 'atom'

module.exports =
class PopupView extends View
  @content: ->
    @div class:'overlay from-top diff-popup native-key-bindings', tabindex: -1, =>
      @div class:'diff-popup-toolbar', =>
        @div class:'drag-bkgd'
        @div class:'drag-bkgd'
        @div class:'drag-bkgd'
        @div class:'drag-bkgd'
        @div class: 'btns', =>
          @span class:'btn icon-left-open'
          @span class:'btn icon-git'
          @span class:'btn icon-right-open'
          @span class:'btn icon-reply'
          @span class:'btn icon-docs'
          @span class:'btn icon-cancel'
        
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
    
    