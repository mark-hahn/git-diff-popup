###
  lib\git-diff-popup.coffee
###

module.exports = 
activate: ->
  console.log 'activate git-diff-popup'
  Diff = require './diff'
  
  @fs              = require 'fs'
  @projPath        = atom.project.getDirectories()[0].path
  @archiveDir      = @projPath + '/.live-archive'
  @haveLiveArchive = @fs.existsSync @archiveDir
  @gitRepo         = atom.project.getRepositories()[0]
  
  if not @gitRepo and not @haveLiveArchive
    atom.confirm
      message: '--- git-diff-popup Error ---\n\n'
      detailedMessage: 'This project must have either a Git repository or ' +
    	                 'an enabled Live-Archive to use the git-diff-popup package.'
      buttons: OK: -> 
    return
  
  @sub = atom.commands.add 'atom-text-editor', 'git-diff-popup:toggle': =>
    if @diff then @diff.close(); @diff = null
    else @diff = new Diff @
  
diffClosed: -> @diff = null
    
deactivate: -> 
  @diff?.close()
  @sub.dispose()
