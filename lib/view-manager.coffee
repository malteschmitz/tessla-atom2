{SIDEBAR_VIEW, OUTPUT_VIEW, FORMATTED_OUTPUT_VIEW } = require "./constants"
Project = require "./project"

module.exports=
  class ViewManager

    constructor: ->
      @views = {}
      @toolBarButtons = {}

      @tesslaMarkers = []
      @tesslaUnsedFunctionMarkers = []
      @tesslaTooltipDecorations = []

      @activeProject = new Project

      atom.workspace.onDidDestroyPaneItem @onDestroyedView
      atom.workspace.onDidStopChangingActivePaneItem (item) =>
        if atom.workspace.isTextEditor item
          @onFileChanged item.getPath()
        else
          @onNoOpenFile()

      atom.workspace.onDidAddTextEditor (event) =>
        @onFileSavedOrAdded event.textEditor.getPath()

      atom.workspace.observeTextEditors (editor) =>
        editor.onDidSave (event) =>
          @onFileSavedOrAdded event.path

        editor.onDidStopChanging (event) =>
          @views.sidebarViews?.update @activeProject


    connectBtns: (btns) ->
      @toolBarButtons = btns


    connectViews: (views) ->
      for key, value of views
        @views[key] = value unless key of @views or @views[key]?

      @views.sidebarViews?.setViewManager @

    addIconsToTabs: ->
      viewTabs = document.querySelectorAll ".tab[data-type=FlexiblePanelView]"

      viewTabs.forEach (tab) ->
        switch tab.children[0].innerHTML
          when "Log" then tab.classList.add "logViewTab"
          when "Warnings" then tab.classList.add "warningsTab"
          when "Errors (TeSSLa)" then tab.classList.add "errorsTeSSLaTab"
          when "Errors (C)" then tab.classList.add "errorsCTab"
          when "Console" then tab.classList.add "consoleTab"


    restoreViews: ->
      Promise.all([
        atom.workspace.toggle @views.consoleView.getURI()
        atom.workspace.toggle @views.errorsCView.getURI()
        atom.workspace.toggle @views.errorsTeSSLaView.getURI()
        atom.workspace.toggle @views.warningsView.getURI()
        atom.workspace.toggle @views.logView.getURI()
        atom.workspace.toggle FORMATTED_OUTPUT_VIEW
        atom.workspace.toggle SIDEBAR_VIEW
      ]).then (views) =>
        viewsContainer = {}

        views.forEach (view) ->
          unless view?.getURI() is FORMATTED_OUTPUT_VIEW or view?.getURI() is SIDEBAR_VIEW
            switch view?.getTitle()
              when "Console" then viewsContainer.consoleView = view
              when "Errors (C)" then viewsContainer.errorsCView = view
              when "Errors (TeSSLa)" then viewsContainer.errorsTeSSLaView = view
              when "Warnings" then viewsContainer.warningsView = view
              when "Log" then viewsContainer.logView = view
              else console.log view

          else
            viewsContainer.sidebarViews = view if view.getURI() is SIDEBAR_VIEW
            viewsContainer.formattedOutputView = view if view.getURI() is FORMATTED_OUTPUT_VIEW
            viewsContainer.unknown.push view unless viewsContainer.formattedOutputView? or viewsContainer.formattedOutputView

        for key, value of viewsContainer
          @views.key ?= value if @views.key?

        @addIconsToTabs()


    onNoOpenFile: ->


    onDestroyedView: (view) ->
      # switch view.item?.getURI()
      #   case CONSOLE_VIEW: this.views.consoleView = null; break;
      #   case ERRORS_C_VIEW: this.views.errorsCView = null; break;
      #   case ERRORS_TESSLA_VIEW: this.views.errorsTeSSLaViews = null; break;
      #   case WARNINGS_VIEW: this.views.warningsView = null; break;
      #   case LOG_VIEW: this.views.logView = null; break;
      #   case SIDEBAR_VIEW: this.views.sidebarViews = null; break;
      #   case FORMATTED_OUTPUT_VIEW: this.views.formattedOutputView = null; break;
      #   default: this.views.unknown = null; break;


    setUpSplitView: ->
      unless @activeProject.cFiles or @activeProject.tesslaFiles
        @showNotSetUpSplitViewNotification()
        return

      atom.workspace.getTextEditors().forEach (editor) ->
        editor.destroy()

      atom.workspace.getPanes()[0].splitRight()

      @activeProject.cFiles.forEach (file) ->
        atom.workspace.open file,
          split: "left"

      @activeProject.tesslaFiles.forEach (file) ->
        atom.workspace.open(file, { split: "right" }).then (editor) ->
          editor.addGutter
            name: "tessla-error-gutter"
            priority: 1000
            visible: yes


    onFileSavedOrAdded: (file) ->
      newProjectPath = atom.project.relativizePath(file)[0]

      if newProjectPath isnt @activeProject.projPath
        @activeProject.setProjPath newProjectPath
        @activeProject.setUpProjectStructure()

      else
        @views.sidebarViews?.update @activeProject


    onFileChanged: (file) ->
      return unless file?

      newProjectPath = atom.project.relativizePath(file)[0]

      unless newProjectPath is @activeProject.projPath
        @activeProject.setProjPath newProjectPath
        @activeProject.setUpProjectStructure()
        @views.sidebarViews?.update(this.activeProject);


    showNoProjectNotification: ->
      message = "There is no active project in your workspace. Open and activate at least one file of the project you want to compile and run in your workspace."

      atom.notifications.addError "Unable to compile and run C code",
        detail: message

      @views.consoleView.addEntry [message]


    showNoCompilableCFilesNotification: ->
      message = "There are no C files to compile in this project. Create at least one C file in this project containing a main function to build a runable binary."

      atom.notifications.addError "Unable to compile C files",
        detail: message

      @views.errorsCView.addEntry [message]


    showNoCBinaryToExecuteNotification: ->
      message = "There is no C binary in the build directory which can be executed. You first have to build your C code to generate a binary."

      atom.notifications.addError "Unable to run binary",
        detail: message

      @views.errorsCView.addEntry [message]


    showNotSetUpSplitViewNotification: ->
      message = "There are no \".tessla\" and \".c\" files to put into split view in the current project. Please open at least one file of your project and activate it in workspace to properly set up the split view. The split view can be set up by right click onto your source file in the text editor and select \"Set up TeSSLa split view\" in the context menu."

      atom.notifications.addWarning "Could not set up the split view",
        detail: message

      @views.warningsView.addEntry [message]


    showNoTeSSLaJSONFoundNotification: ->
      message = "No TeSSLa JSON file found!";

      atom.notifications.addError "Unable to find TeSSLa JSON file",
        detail: message

      @views.consoleView.addEntry [message]


    showNoActiveProjectForSplitViewNotification: ->
      message = "No Project currently active. To set up the split view at least one file should be active for setting up the split view"

      atom.notifications.addWarning "Could not set up the split view",
        detail: message

      @views.warningsView.addEntry [message]


    showCurrentlyRunningProcessNotification: ->
      message = "There is a process that is currently running. A new action can only be performed if there is no action currently running."

      atom.notifications.addWarning "Unable to perform action",
        detail: message

      @views.consoleView.addEntry [message]


    onHighlightUnusedFunctions: ({ unusedFunctions, tesslaFile }) ->
      editors = workspace.getTextEditors()
      editorFile = null

      editors.forEach (editor) ->
        editorFile = editor if editor?.getPath() is tesslaFile

      if editorFile?
        @tesslaUnsedFunctionMarkers.forEach (marker) -> marker.destroy()
        @tesslaUnsedFunctionMarkers = []

        text = editorFile.getText()

        lineCounter = 0

        text.split("\n").forEach (line) =>
          unusedFunctions.forEach (func) =>
            lookupText = "function_calls(\"#{func}\")";
            idx = line.indexOf lookupText

            unless idx is -1
              range = new Range new Point(lineCounter, idx), new Point(lineCounter, idx + lookupText.length)
              marker = editorFile.markBufferRange range

              @tesslaUnsedFunctionMarkers.push marker

              editorFile.decorateMarker marker,
                type: "highlight"
                class: "tessla-unused-function"

          lineCounter++


    highlightTeSSLaError: ({ error, file }) ->
      regex = /\b(ParserError)\(\(([\s,0-9-]+)\):\s(.*)\)/g
      match = regex.exec error

      if match?
        @tesslaMarkers.forEach (marker) -> marker.destroy()
        @tesslaMarkers = []
        @tesslaTooltipDecorations = []

        location = match[2]
        text = match[3]

        workspace.open file,
          split: "right"
          searchAllPanes: yes
        .then (editor) =>
          start = (location.split(" - ")[0]).split ","
          start = new Point start[0] - 1, start[1] - 1

          end = (location.split(" - ")[1]).split ","
          end = new Point end[0] - 1, end[1] - 1

          editor.setCursorBufferPosition start
          editor.scrollToCursorPosition()

          range = new Range start, end
          marker = editor.markBufferRange range

          @tesslaMarkers.push marker

          editor.decorateMarker marker,
            type: "highlight"
            class: "tessla-syntax-error"

          tt = document.createElement "div"
          ttLabel = document.createElement "span"
          ttText = document.createElement "span"

          ttLabel.textContent = "error"
          ttText.textContent = text

          ttLabel.classList.add "error-label"
          tt.appendChild ttLabel
          tt.appendChild ttText

          tooltip = editor.decorateMarker marker,
            type: "overlay"
            class: "tessla-syntax-tooltip"
            item: tt
            position: "tail"

          @tesslaTooltipDecorations.push tooltip

          gutter = editor.gutterWithName "tessla-error-gutter"

          unless gutter?
            gutter = editor.addGutter
              name: "tessla-error-gutter"
              priority: 1000
              visible: yes

          gutter.decorateMarker marker,
            type: "gutter"
            class: "tessla-syntax-dot"


    onHideErrorMarkers: ->
      return if @tesslaMarkers.length is 0

      @tesslaTooltipDecorations.forEach (decoration) -> decoration.destroy()
      @tesslaTooltipDecorations = []


    disableButtons: ->
      @toolBarButtons.BuildAndRunCCode.setEnabled no
      @toolBarButtons.BuildCCode.setEnabled no
      @toolBarButtons.RunCCode.setEnabled no
      @toolBarButtons.BuildAndRunProject.setEnabled no


    enableButtons: ->
      @toolBarButtons.BuildAndRunCCode.setEnabled yes
      @toolBarButtons.BuildCCode.setEnabled yes
      @toolBarButtons.RunCCode.setEnabled yes
      @toolBarButtons.BuildAndRunProject.setEnabled yes


    enableStopButton: ->
      @toolBarButtons.Stop.setEnabled yes


    disableStopButton: ->
      @toolBarButtons.Stop.setEnabled no


    removeTeSSLaSourceMarkers: ->
      @tesslaMarkers.forEach (marker) -> marker.destroy()
      @tesslaMarkers = []
      @tesslaTooltipDecorations = []


    saveEditors: =>
      activeEditor = atom.workspace.getActiveTextEditor()
      currentProjPath = @activeProject.projPath

      atom.workspace.getTextEditors().forEach (editor) =>
        editor.save() unless editor?.getPath()? is @activeProject.projPath

      activeEditor?.save()
      @activeProject.setProjPath currentProjPath
