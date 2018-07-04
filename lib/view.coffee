Project = require "./project"
MessageQueue = require "./message-queue"

{ SIDEBAR_VIEW, OUTPUT_VIEW, FORMATTED_OUTPUT_VIEW } = require "./constants"

module.exports=
  class View

    constructor: ->
      # intialize instance variables
      @views = {}
      @toolBarButtons = {}

      @tesslaMarkers = []
      @tesslaUnsedFunctionMarkers = []
      @tesslaTooltipDecorations = []

      @activeProject = new Project

      # define queues
      @logQueue = new Queue
      @consoleQueue = new Queue
      @errorsCQueue = new Queue
      @errorsTeSSLaQueue = new Queue
      @warningsQueue = new Queue

      # bind event listener
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


    printMessage: ({channel, type, title, label, message}) ->
      # do not anything if not all fields defined
      if not (channel?) or not(type?) or not(title?) or not(label) or not(message)
        return

      # define a function that will construct a valid message queue message for us
      constructMessage = (labeled, obj) ->
        result = {}
        result.content = obj.content
        result.label = obj.label if labeled
        if obj.type is "listEntry"
          result.title =  obj.title
          result.isListEntry = yes
        else
          result.isListEntry = no
        # pass result to caller
        result

      # define a function that will add the message to the view component
      logMessage = (labeled, view, obj) ->
        result = []
        result.push obj.label if labeled
        result.push obj.content
        if obj.isListEntry
          view.addListEntry obj.title, result
        else
          view.addEntry result

      switch channel
        when 'console'
          @consoleQueue.enqueueEntry constructMessage no, { type, title, label, message }
          logMessage(no, @views.logView, msg) for msg in @consoleQueue.flush()
        when 'errorsC'
          @errorsCQueue.enqueueEntry constructMessage no, { type, title, label, message }
          logMessage(no, @views.errorsCView, msg) for msg in @errorsCQueue.flush()
        when 'errorsTeSSLa'
          @errorsTeSSLaQueue.enqueueEntry constructMessage no, { type, title, label, message }
          logMessage(no, @views.errorsTeSSLaView, msg) for msg in @errorsTeSSLaQueue.flush()
        when 'warnings'
          @warningsQueue.enqueueEntry constructMessage no, { type, title, label, message }
          logMessage(no, @views.warningsView, msg) for msg in @warningsQueue.flush()
        when 'log'
          @logQueue.enqueueEntry constructMessage yes, { type, title, label, message }
          logMessage(yes, @views.logView, msg) for msg in @logQueue.flush()


    onDidSetup: ->
      # define a function that will add the message to the view component
      logMessage = (labeled, view, obj) ->
        result = []
        result.push obj.label if labeled
        result.push obj.content
        if obj.isListEntry
          view.addListEntry obj.title, result
        else
          view.addEntry result

      # flush all queues
      logMessage(no, @views.logView, msg) for msg in @logQueue.flush()
      logMessage(no, @views.logView, msg) for msg in @consoleQueue.flush()
      logMessage(no, @views.errorsCView, msg) for msg in @errorsCQueue.flush()
      logMessage(no, @views.errorsTeSSLaView, msg) for msg in @errorsTeSSLaQueue.flush()
      logMessage(no, @views.warningsView, msg) for msg in @warningsQueue.flush()


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
      # console.log "[TeSSLa2][debug] view-manager.coffee:58: Restore views."
      Promise.all([
        atom.workspace.open @views.consoleView.getURI()
        atom.workspace.open @views.errorsCView.getURI()
        atom.workspace.open @views.errorsTeSSLaView.getURI()
        atom.workspace.open @views.warningsView.getURI()
        atom.workspace.open @views.logView.getURI()
        atom.workspace.open FORMATTED_OUTPUT_VIEW
        atom.workspace.open SIDEBAR_VIEW
      ]).then (views) =>
        viewsContainer = {}

        for view in views
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
      # console.log "[TeSSLa2][debug] view-manager.coffee:107: Set up split view.", @activeProject
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
      # console.log "[TeSSLa2][debug] view-manager.coffee:141: Changed file.", file
      return unless file?

      newProjectPath = atom.project.relativizePath(file)[0]
      #console.log file, newProjectPath
      #console.log "[TeSSLa2][debug] view-manager.coffee:141: Change project directory ...", newProjectPath

      unless newProjectPath is @activeProject.projPath
        @activeProject.setProjPath newProjectPath
        @activeProject.setUpProjectStructure()
        @views.sidebarViews?.update @activeProject

      # console.log "[TeSSLa2][debug] view-manager.coffee:153: New project ...", @activeProject


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


    showSuccessfullyInstrumentedNotification: ->
      message = "Verification of project files successfully finished."
      atom.notifications.addSuccess message
      @views.logView.addEntry ["message", message]


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


    saveEditors: =>
      activeEditor = atom.workspace.getActiveTextEditor()
      currentProjPath = @activeProject.projPath

      atom.workspace.getTextEditors().forEach (editor) =>
        editor.save() unless editor?.getPath()? is @activeProject.projPath

      activeEditor?.save()
      @activeProject.setProjPath currentProjPath

    showIndeterminateProgress: (title, text, dismissable=yes) ->
      # show notification to user that a pull request will start that may take
      # a few minutes if the latest version of tessla2 is not already downloaded
      notification = atom.notifications.addInfo title,
        detail: text
        dismissable: dismissable

      progressWrapper = document.createElement "div"
      progressWrapper.classList.add "block"

      progress = document.createElement "progress"
      progress.classList.add "block", "full-width-progress"

      progressWrapper.appendChild progress

      try
        notificationView = atom.views.getView notification
        notificationViewContent = notificationView.element.querySelector ".detail-content"
        notificationViewContent?.appendChild progressWrapper
      catch _

      # return the notification object back
      return notification
