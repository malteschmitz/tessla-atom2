path = require "path"

module.exports=
  class SourceHighlighter

    constructor: ->
      # get all editors to keep track to which one a marker was attached
      @markersInEditor = {}

      @updateObservedEditors()


    updateObservedEditors: ->
      # remember all currently open files to remove those text-editors which are
      # not used anymore.
      currentMarkersInEditor = {}
      visitedEditors = []

      #iterate over editors
      for editor in atom.workspace.getTextEditors()
        if editor isnt null
          identifier = path.join editor.getPath(), editor.getTitle()
          visitedEditors.push identifier

          if not (identifier of @markersInEditor)
            currentMarkersInEditor[identifier] = []
          else
            currentMarkersInEditor[identifier] = @markersInEditor[identifier]

      # remove editors that are not needed any anymore
      #for key, value of @markersInEditor

      # replace old markers object with new one
      @markersInEditor = currentMarkersInEditor

      console.log @markersInEditor
