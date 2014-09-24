###
 lib\diff-popup.coffee
###

module.exports = 
  
  activate: ->
    
    @delayedActivate()
    
  delayedActivate: ->
    @fs            = require 'fs'
    @pathUtil      = require 'path'
    {@load, @save} = require 'text-archive-engine'
    
    @rootDir    = atom.project.getRootDirectory().path
    @archiveDir = @rootDir + '/.live-archive'
    @hasLiveArchive = @fs.existsSync @archiveDir
    

  deactivate: -> 
  