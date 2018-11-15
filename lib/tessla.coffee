{ CompositeDisposable, Disposable } = require("atom")
packageDeps = require("atom-package-deps")
childProcess = require("child_process")

{DockerMediator} = require("./utils/docker-mediator")
SidebarView = require("./views/sidebar-view")
OutputView = require("./views/output-view")
Controller = require("./controllers/controller")
{SIDEBAR_VIEW, FORMATTED_OUTPUT_VIEW, TESSLA_CONTAINER_NAME} = require("./utils/constants")
{isSet} = require("./utils/utils")
TeSSLaAutocompleter = require("./autocomplete/tessla-autocompleter")
Logger = require("./utils/Logger")
TeSSLaLinter = require("./linter/tessla-linter")
{createToolbar} = require("./views/toolbar.coffee")

module.exports=
  subscriptions: null
  toolbar: null
  controller: null
  flexiblePanelsManager: null
  hide: yes

  # a promise that indicates if console panels are ready to use
  consoleReadyResolve: null
  consoleReady: null

  # a promise that indicates if the toolbar is set up
  toolBarReadyResolve: null
  toolBarReady: null

  # a promise that indicates if the sidebar is set up
  sidebarReadyResolve: null
  sidebarReady: null

  initialize: ->
    Logger.log("initialize()")
    @consoleReady = new Promise((resolve, reject) =>
      @consoleReadyResolve = resolve
    )
    @toolBarReady = new Promise((resolve, reject) =>
      @toolBarReadyResolve = resolve
    )
    @sidebarReady = new Promise((resolve, reject) =>
      @sidebarReadyResolve = resolve
    )
    @controller = new Controller()
    @subscriptions = new CompositeDisposable


  activate: ->
    Logger.log("activate()")
    packageDeps.install("tessla2", false).then((response) =>
      @subscriptions.add(
        # register commands
        atom.commands.add("atom-workspace", {
          # housekeeping stuff
          "tessla2:activate": @activate
          "tessla2:deactivate": @deactivate
          "tessla2:toggle": @toggle
          # visual stuff
          "tessla2:set-up-split-view": @controller.setUpSplitView
          "tessla2:reset-view": @controller.restoreViews
          # compilation stuff
          "tessla2:create-trace": @controller.onCreateTrace
          "tessla2:build-and-run-c-code": @controller.onCompileAndRunCCode
          "tessla2:verify-spec": @controller.onCompileAndRunProject
          "tessla2:stop-current-process": @controller.onStopRunningProcess
        }),
        # add custom openers for custom UI elements
        atom.workspace.addOpener((URI) ->
          if URI is SIDEBAR_VIEW
            return new SidebarView({ title: "Functions", URI: SIDEBAR_VIEW })
          if URI is FORMATTED_OUTPUT_VIEW
            return new OutputView({ title: "Formatted output", URI: FORMATTED_OUTPUT_VIEW })
        ),
        # add clean up stuff for custom UI elements...
        new Disposable(() ->
          for item in atom.workspace.getPaneItems()
            if item instanceof SidebarView or item instanceof OutputView
              item.destroy()
        )
      )

      # open custom dock items
      Promise.all([
        atom.workspace.open FORMATTED_OUTPUT_VIEW
        atom.workspace.open SIDEBAR_VIEW
      ]).then((views) =>
        viewsContainer = {}
        viewsContainer.unknown = []
        for view in views
          switch view?.getURI()
            when SIDEBAR_VIEW           then viewsContainer.sidebarViews = view
            when FORMATTED_OUTPUT_VIEW  then viewsContainer.formattedOutputView = view
        @sidebarReadyResolve(viewsContainer)
      )

      # now wait for toolbar setup completion
      return @toolBarReady
    ).then((buttons) =>
      @controller.connectToToolbarBtns(buttons)
      return @sidebarReady
    ).then((views) =>
      @controller.connectToSidebarViews(views)
      return @consoleReady
    ).then((views) =>
      @controller.connectToConsoleViews(views)
      @controller.addIconsToConsoleTabs()
      @controller.setUpSplitView()
      new DockerMediator().pull().then((log) =>
        for item in log
          if item.type is "entry"
            views.logView.addEntry([item.label, item.msg])
          if item.type is "listEntry"
            views.logView.addListEntry(item.title, [item.label, item.msg])
        atom.workspace.getCenter().activate()
        @controller.onViewSetUpReady()
      )
    ).catch((error) =>
      Logger.err(error)
      atom.notifications.addFatalError "Could not start TeSSLa package",
        detail: "Package dependencies could not be installed. The package was not started because the TeSSLa package will not run properly without this dependencies.\n#{error.message}"
    )


  deactivate: ->
    Logger.log("deactivate()")
    # destroy controller
    @controller.dispose()
    # tear down toolbar
    if @toolbar?
      @toolbar.removeItems()
      @toolbar = null
    # clean up subscriptions
    @subscriptions.dispose() if @subscriptions?
    # clean up view elements
    @flexiblePanelsManager.destroy() if @flexiblePanelsManager?
    # stop using docker container
    childProcess.execSync("docker rm -f #{TESSLA_CONTAINER_NAME}")


  toggle: ->
    Logger.log("toggle()")
    if not @hide
      # show sidebar items
      atom.workspace.open(FORMATTED_OUTPUT_VIEW)
      atom.workspace.open(SIDEBAR_VIEW)
      # show flexible panel items
      @flexiblePanelsManager.showPanels()
      # show tool bar
      atom.config.set("tool-bar.visible", yes)
    else
      # hide sidebar items
      atom.workspace.hide(FORMATTED_OUTPUT_VIEW)
      atom.workspace.hide(SIDEBAR_VIEW)
      # hide flexible panel items
      @flexiblePanelsManager.hidePanels()
      # hide tool bar
      atom.config.set("tool-bar.visible", no)
    # invert hide flag
    @hide = not @hide


  consumeFlexiblePanels: (@flexiblePanelsManager) ->
    Logger.log("consumeFlexiblePanels()")
    logCols = [{
      name: "Type", align: "center", fixedWidth: 70, type: "label"
    }, {
      name: "Description", indentWrappedText: yes
    }, {
      name: "Time", align: "center", fixedWidth: 95, type: "time"
    }]

    cols = [{
      name: "Description", type: "text"
    }, {
      name: "Time", align: "center", fixedWidth: 95, type: "time"
    }]

    logLbls = [{
      type: "command", background: "#F75D59", color: "#FFF"
    }, {
      type: "message", background: "#3090C7", color: "#FFF"
    }, {
      type: "Docker", background: "#8E5287", color: "#FFF"
    }, {
      type: "TeSSLa RV", background: "#5BB336", color: "#FFF"
    }, {
      type: "status", background: "#FF996E", color: "#FFF"
    }, {
      type: "clang", background: "#C00", color: "#FFF"
    }]

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
      # indicate that setup is done now!
      @consoleReadyResolve(viewsContainer)


  consumeToolBar: (getToolBar) ->
    Logger.log("consumeToolBar()")
    @toolBar = getToolBar("tessla2")
    @toolBar.onDidDestroy(() => @toolBar = null)
    @toolBarReadyResolve(createToolbar(@toolBar))

  provideLinter: () ->
    Logger.log("provideLinter()")
    return new TeSSLaLinter

  provideAutocomplete: () ->
    Logger.log("provideAutocomplete()")
    return new TeSSLaAutocompleter
