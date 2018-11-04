{ CompositeDisposable, Disposable } = require "atom"
{SIDEBAR_VIEW, OUTPUT_VIEW, FORMATTED_OUTPUT_VIEW } = require "../utils/constants"
Project = require "../utils/project"

module.exports=
  class ViewManager

    constructor: ->
      @views = {}
      @toolBarButtons = {}
      @subscriptions = new CompositeDisposable
      @activeProject = new Project

      atom.workspace.onDidDestroyPaneItem @onDestroyedView
      atom.workspace.onDidAddTextEditor (event) =>
        @onFileSavedOrAdded event.textEditor.getPath()
      atom.workspace.observeTextEditors (editor) =>
        editor.onDidSave (event) =>
          @onFileSavedOrAdded event.path
        editor.onDidStopChanging (event) =>
          @views.sidebarViews?.update @activeProject

      @subscriptions.add(
        new Disposable(=>
          @activeProject.dispose()
        )
      )


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
      # unless @activeProject.cFiles or @activeProject.tesslaFiles
      #   @showNotSetUpSplitViewNotification()
      #   return
      #
      # atom.workspace.getTextEditors().forEach (editor) ->
      #   editor.destroy()
      #
      # atom.workspace.getPanes()[0].splitRight()
      #
      # @activeProject.cFiles.forEach (file) ->
      #   atom.workspace.open file,
      #     split: "left"
      #
      # @activeProject.tesslaFiles.forEach (file) ->
      #   atom.workspace.open(file, { split: "right" }).then (editor) ->
      #     editor.addGutter
      #       name: "tessla-error-gutter"
      #       priority: 1000
      #       visible: yes


    onFileSavedOrAdded: (file) ->
      @views.sidebarViews?.update @activeProject

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


    showNoCompilableTraceFilesNotification: ->
      message = "There are no trace files to instrument in this project. Create at least one trace file in this project which can be instrumented."
      atom.notifications.addError "Unable to instrument trace file",
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

    showNoTargetsSpecified: ->
      message = "There are no targets specified that contain compilation information"
      atom.notifications.addError("Unable to find targets",
        detail: message
      )
      @views.logView.addEntry([message])


    disableButtons: ->
      @toolBarButtons.BuildAndRunCCode.setEnabled no
      @toolBarButtons.BuildCCode.setEnabled no
      @toolBarButtons.RunCCode.setEnabled no
      @toolBarButtons.CreateTrace.setEnabled no
      @toolBarButtons.BuildAndRunProject.setEnabled no
      @toolBarButtons.RunProjectByTrace.setEnabled no


    enableButtons: ->
      @toolBarButtons.BuildAndRunCCode.setEnabled yes
      @toolBarButtons.BuildCCode.setEnabled yes
      @toolBarButtons.RunCCode.setEnabled yes
      @toolBarButtons.CreateTrace.setEnabled yes
      @toolBarButtons.BuildAndRunProject.setEnabled yes
      @toolBarButtons.RunProjectByTrace.setEnabled yes


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

    dispose: =>
      @subscriptions.dispose()
