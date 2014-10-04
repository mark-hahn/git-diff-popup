###
  lib\diff-popup.coffee
###

module.exports = 

  configDefaults:
    maximumLinesInGitGap: 2
  
  activate: ->
    Diff = require './diff'
    
    @fs              = require 'fs'
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
    
    atom.workspaceView.command "diff-popup:toggle", => 
      if @diff then @diff.close(); @diff = null
      else @diff = new Diff @
    
  diffClosed: -> @diff = null
      
  deactivate: -> @diff.close()
  