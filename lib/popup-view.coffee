{View} = require 'atom'

module.exports =
class PopupView extends View
  @content: ->
    @div class: 'popup-view overlay from-top', =>

  initialize: ->
    atom.workspaceView.command "diff-popup:toggle", => @toggle()

  toggle: ->
    console.log "diff-popup was toggled"
    if @hasParent() then @detach()
    else atom.workspaceView.append(this)
      
  destroy: ->
    @detach()

