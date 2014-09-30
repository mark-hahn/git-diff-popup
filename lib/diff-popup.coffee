###
  lib\diff-popup.coffee
###

module.exports = 

  configDefaults:
    maximumLinesInGitGap: 3
  
  activate: ->
    @fs  = require 'fs'
    Diff = require './diff'
    
    @projPath        = atom.project.getRootDirectory().path
    @archiveDir      = @projPath + '/.live-archive'
    @haveLiveArchive = @fs.existsSync @archiveDir
    @gitRepo         = atom.project.getRepo()
    
    if not @gitRepo and not @haveLiveArchive
      atom.confirm
        message: '--- Diff-Popup Error ---\n\n'
        detailedMessage: 'This project must have either a Git repository or ' +
      	                 'an enabled Live-Archive to use the Diff-Popup package.'
        buttons: OK: -> return
    
    @PopupView    = require './popup-view'
    @archiveDir   = @projPath + '/.live-archive'
    @maxGitGap    = atom.config.get 'diff-popup.maximumLinesInGitGap'
    {@load,@save} = require 'text-archive-engine'

    atom.workspaceView.command "diff-popup:toggle", =>
      if not (editorView = atom.workspaceView.getActiveView()) or
         not (editor = editorView.getModel()) then return

      if (diff = editor.diffPopup) then diff.toggle()
      else editor.diffPopup = new Diff @, editorView, editor
      