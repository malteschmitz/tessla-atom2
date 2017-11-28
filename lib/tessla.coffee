{ CompositeDisposable, Disposable } = require "atom"
packageDeps = require "atom-package-deps"
path = require "path"
os = require "os"
fs = require "fs"
childProcess = require "child_process"
Docker = require "dockerode"
docker = new Docker

SidebarView = require "./sidebar-view"
OutputView = require "./output-view"
Controller = require "./controller"
ViewManager = require "./view-manager"
{SIDEBAR_VIEW, FORMATTED_OUTPUT_VIEW, TESSLA_IMAGE_NAME, TESSLA_CONTAINER_NAME, TESSLA_REGISTRY} = require "./constants"

module.exports=
  subscriptions: null
  activeProject: null
  toolbar: null
  viewManager: null
  controller: null
  toolBarButtons: {}
  flexiblePanelsManager: null
  containerDir: ""
  hide: yes

  activate: ->
    #init instance variables
    @viewManager = new ViewManager
    @containerDir = path.join os.homedir(), ".tessla-env"

    # create a controller object
    @controller = new Controller @viewManager

    # install package dependencies or skip installation if deps are already
    # installed
    packageDeps.install("tessla2", false).then (response) =>
      # try to pull latest repo version of TeSSLa2
      @controller.dockerPullRequest()

      # create view manager
      @subscriptions = new CompositeDisposable

      @subscriptions.add atom.commands.add "atom-workspace",
        "tessla2:activate": => @activate()
        "tessla2:deactivate": => @deactivate()
        "tessla2:toggle": => @toggle()
        "tessla2:set-up-split-view": => @viewManager.setUpSplitView()
        "tessla2:build-and-run-c-code": => @controller.onCompileAndRunCCode()
        "tessla2:build-c-code": => @controller.onBuildCCode buildAssembly: no
        "tessla2:run-c-code": => @controller.onRunBinary {}
        "tessla2:stop-current-process": => @controller.onStopRunningProcess()
        "tessla2:build-and-run-project": => @controller.onCompileAndRunProject()
        "tessla2:reset-view": => @viewManager.restoreViews()

      @subscriptions.add atom.workspace.addOpener (URI) ->
        switch URI
          when SIDEBAR_VIEW          then new SidebarView { title: "Functions", URI: SIDEBAR_VIEW }
          when FORMATTED_OUTPUT_VIEW then new OutputView { title: "Formatted output", URI: FORMATTED_OUTPUT_VIEW }

      @subscriptions.add new Disposable ->
        for item in atom.workspace.getPaneItems()
          if item instanceof SidebarView or item instanceof OutputView
            item.destroy()

      # open sidebar items
      Promise.all([
        atom.workspace.open FORMATTED_OUTPUT_VIEW
        atom.workspace.open SIDEBAR_VIEW
      ]).then (views) =>
        viewsContainer = {}
        viewsContainer.unknown = []

        for view in views
          switch view?.getURI()
            when SIDEBAR_VIEW then viewsContainer.sidebarViews = view
            when FORMATTED_OUTPUT_VIEW then viewsContainer.formattedOutputView = view
            else viewsContainer.unknown.push view

        # now give created the views to the view manager
        @viewManager.connectViews viewsContainer

        # give focus to text editors
        atom.workspace.getCenter().activate()

        # get the right project
        for editor in atom.workspace.getTextEditors()
          if atom.views.getView(editor).offsetParent? and editor?
            @viewManager.activeProject.setProjPath path.dirname editor.getPath()

        # now everything is done... split text editors into two views
        @viewManager.setUpSplitView()

    # if dependencies can not be installed the we do not start anything within
    # this package
    .catch (error) =>
      console.log error
      atom.notifications.addFatalError "Could not start TeSSLa package",
        detail: "Package dependencies could not be installed. The package was not started because the TeSSLa package will not run properly without this dependencies.\n#{error.message}"


  deactivate: ->
    # tear down toolbar
    if @toolbar?
      @toolbar.removeItems()
      @toolbar = null

    # clean up subscriptions
    @subscriptions.dispose() if @subscriptions?

    # clean up view elements
    @flexiblePanelsManager.destroy() if @flexiblePanelsManager?

    # stop using docker container
    console.log "docker rm -f #{TESSLA_CONTAINER_NAME}"
    childProcess.spawnSync "docker", ["rm", "-f", TESSLA_CONTAINER_NAME]


  toggle: ->
    if not @hide
      # hide sidebar items
      atom.workspace.open FORMATTED_OUTPUT_VIEW
      atom.workspace.open SIDEBAR_VIEW

      # hide flexible panel items
      @flexiblePanelsManager.showPanels()

      # hide tool bar
      atom.config.set 'tool-bar.visible', yes
    else
      # hide sidebar items
      atom.workspace.hide FORMATTED_OUTPUT_VIEW
      atom.workspace.hide SIDEBAR_VIEW

      # hide flexible panel items
      @flexiblePanelsManager.hidePanels()

      # hide tool bar
      atom.config.set 'tool-bar.visible', no

    # invert hide flag
    @hide = not @hide


  consumeFlexiblePanels: (@flexiblePanelsManager) ->
    logCols = [
        name: "Type", align: "center", fixedWidth: 70, type: "label"
      ,
        name: "Description", indentWrappedText: yes
      ,
        name: "Time", align: "center", fixedWidth: 95, type: "time"
    ]

    cols = [
        name: "Description", type: "text"
      ,
        name: "Time", align: "center", fixedWidth: 95, type: "time"
    ]

    logLbls = [
        type: "command", background: "#F75D59", color: "#FFF"
      ,
        type: "message", background: "#3090C7", color: "#FFF"
      ,
        type: "Docker", background: "#8E5287", color: "#FFF"
      ,
        type: "TeSSLa RV", background: "#FF996E", color: "#FFF"
      ,
        type: "status", background: "#5BB336", color: "#FFF"
    ]

    Promise.all([
      @flexiblePanelsManager.createFlexiblePanel
        title: "Console"
        columns: [name: "Description"]
        useMonospaceFont: yes
        hideTableHead: yes
        hideCellBorders: yes
      @flexiblePanelsManager.createFlexiblePanel
        title: "Errors (C)"
        columns: cols
        useMonospaceFont: yes
        hideTableHead: yes
      @flexiblePanelsManager.createFlexiblePanel
        title: "Errors (TeSSLa)"
        columns: cols
        useMonospaceFont: yes
        hideTableHead: yes
      @flexiblePanelsManager.createFlexiblePanel
        title: "Warnings"
        columns: cols
        useMonospaceFont: yes
        hideTableHead: yes
      @flexiblePanelsManager.createFlexiblePanel
        title: "Log"
        columns: logCols
        labels: logLbls
        useMonospaceFont: yes
    ]).then (views) =>
      viewsContainer = {}
      viewsContainer.unknown = []

      for view in views
        switch view?.getTitle()
          when "Console" then viewsContainer.consoleView = view
          when "Errors (C)" then viewsContainer.errorsCView = view
          when "Errors (TeSSLa)" then viewsContainer.errorsTeSSLaView = view
          when "Warnings" then viewsContainer.warningsView = view
          when "Log" then viewsContainer.logView = view
          else viewsContainer.unknown.push view

      if @viewManager?
        @viewManager.connectViews viewsContainer
        @viewManager.addIconsToTabs()
        @controller.onViewSetUpReady()


  consumeToolBar: (getToolBar) ->
    @toolBar = getToolBar "tessla2"

    @toolBarButtons.BuildAndRunCCode = @toolBar.addButton
      icon: "play-circle"
      callback: "tessla2:build-and-run-c-code"
      tooltip: "Builds and runs C code from project directory"
      iconset: "fa"

    @toolBarButtons.BuildCCode = @toolBar.addButton
      icon: "gear-a"
      callback: "tessla2:build-c-code"
      tooltip: "Builds the C code of this project into a binary"
      iconset: "ion"

    @toolBarButtons.RunCCode = @toolBar.addButton
      icon: "play"
      callback: "tessla2:run-c-code"
      tooltip: "Runs the binaray compiled from C code"
      iconset: "ion"

    @toolBar.addSpacer()

    @toolBarButtons.BuildAndRunProject = @toolBar.addButton
      icon: "ios-circle-filled"
      callback: "tessla2:build-and-run-project"
      tooltip: "Builds and runs C code and analizes runtime behavior"
      iconset: "ion"

    @toolBar.addSpacer()

    @toolBarButtons.Stop = @toolBar.addButton
      icon: "android-checkbox-blank"
      callback: "tessla2:stop-current-process"
      tooltip: "Stops the process that is currently running"
      iconset: "ion"
    @toolBarButtons.Stop.setEnabled no

    @toolBar.addSpacer()

    @toolBar.addButton
      icon: "columns"
      callback: "tessla2:set-up-split-view"
      tooltip: "Set up split view"
      iconset: "fa"

    @toolBarButtons.showLog = @toolBar.addButton
      icon: "window-maximize"
      callback: "tessla2:reset-view"
      tooltip: "Restore all view Components"
      iconset: "fa"

    @viewManager.connectBtns @toolBarButtons

    atom.config.set "tool-bar.iconSize", "16px"
    atom.config.set "tool-bar.position", "Right"


  #config:
    # animationSpeed:
    #   type: "integer"
    #   default: 200
    #   order: 3
    #   title: "Animation speed"
    #   description: "This will set the speed of animations used in this package. The time is represented in milliseconds."
