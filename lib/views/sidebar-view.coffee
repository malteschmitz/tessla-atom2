
SidebarViewElement = require "./sidebar-view-element"
FileManager = require "../controllers/file-manager"

module.exports=
  class SidebarView

    constructor: (@config) ->
      @title = @config.title
      @URI = @config.URI
      @viewManager = null

      @element = document.createElement "div"
      @element.classList.add "sidebar-wrapper"

      header = document.createElement "h4"
      header.classList.add "align-center", "block", "highlight", "padding-5px"
      header.innerHTML = "C Functions"

      listWrapper = document.createElement "div"
      listWrapper.classList.add "list-wrapper"

      list = document.createElement "ul"
      list.classList.add "list-group"

      placeholder = document.createElement "span"
      placeholder.classList.add "placeholder"
      placeholder.innerHTML = "No functions found"

      list.appendChild placeholder
      listWrapper.appendChild list

      @element.appendChild header
      @element.appendChild listWrapper


    setViewManager: (viewManager) ->
      @viewManager = viewManager


    addEntry: ({name, file, line, column, observed, exists}) ->
      entry = new SidebarViewElement
        name: name
        file: file
        line: line.toString()
        column: column.toString()
        observed: observed
        exists: exists
        viewManager: this.viewManager

      listGroup = @element.getElementsByClassName("list-group")[0]
      placeholder = listGroup.querySelector ".placeholder"

      listGroup.appendChild entry.element
      listGroup.removeChild placeholder if placeholder?


    clearEntries: ->
      listView = @element.getElementsByClassName("list-group")[0]
      listView.removeChild listView.lastChild while listView.hasChildNodes()

      placeholder = document.createElement "span"
      placeholder.classList.add "placeholder"
      placeholder.innerHTML = "No functions found"

      listView.appendChild placeholder


    getTitle: ->
      @title

    getURI: ->
      @URI

    getDefaultLocation: ->
      "right"

    getAllowedLocations: ->
      ["right", "center", "left"]

    destroy: ->
      @element.remove()

    update: (activeProject) ->
      cFiles = activeProject.cFiles
      tFiles = activeProject.tesslaFiles

      @clearEntries()

      return unless cFiles? or tFiles?

      cFunctions = []
      tFunctions = []
      list = []

      cFiles.forEach (file) ->
        FileManager.collectCFunctionsFromSourceFile
          sourceFile: file
          projectPath: activeProject.projPath
        .forEach (func) ->
          list.push func

      list.forEach (cFile) ->
        cFile.observed = no
        cFile.exists = yes

      tFiles.forEach (file) ->
        FileManager.collectCFunctionsFromSourceFile
          sourceFile: file
          projectPath: activeProject.projPath
        .forEach (func) ->
          definedInCFiles = no

          list.forEach (listFunc) ->
            if listFunc.functionName is func.functionName
              definedInCFiles = yes
              listFunc.observed = yes

          unless definedInCFiles
            func.exists = no
            func.observed = no
            list.push func

      list.sort (a, b) -> a.functionName.localeCompare b.functionName
      list.forEach (entry) =>
        @addEntry
          name: entry.functionName
          file: entry.fileName
          line: entry.line
          column: entry.column
          observed: entry.observed
          exists: entry.exists
