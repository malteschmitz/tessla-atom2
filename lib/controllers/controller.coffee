{ CompositeDisposable, Disposable } = require("atom")
path = require("path")
childProcess = require("child_process")
fs = require("fs-extra")
os = require("os")
docker = new require("dockerode")()
scanFolder = require("scan-folder")

{DockerMediator} = require("../utils/docker-mediator")
Project = require("../utils/project")
{SIDEBAR_VIEW, FORMATTED_OUTPUT_VIEW, TESSLA_REGISTRY, TESSLA_IMAGE_NAME, TESSLA_CONTAINER_NAME} = require("../utils/constants")
{isSet} = require("../utils/utils")
Logger = require("../utils/logger")

module.exports=
  class Controller
    constructor: () ->
      @runningProcess = null
      @currentlyMounting = no
      @pullDone = no
      @subscriptions = new CompositeDisposable
      @activeProject = new Project
      @toolbarButtons = null
      @sidebarView = null
      @formattedOutputView = null
      @consoleViews = null

      @subscriptions.add(
        new Disposable(=>
          @activeProject.dispose()
        )
      )

      @activeProject.on("project-dir-changed", =>
        if not @pullDone
          return
        @sidebarView.update(@activeProject)
        @mountProjectIntoContainer().catch((err) =>
          Logger.err(err)
        )
      )


    onViewSetUpReady: ->
      Logger.log("Controller.onViewSetUpReady()")
      @pullDone = yes
      @sidebarView.update(@activeProject)
      @mountProjectIntoContainer().catch((err) =>
        Logger.err(err)
      )


    connectToToolbarBtns: (btns) =>
      @toolbarButtons = btns
      Logger.log("Controller.connectToToolbarBtns()", @toolbarButtons)


    connectToSidebarViews: (views) =>
      @sidebarView = views.sidebarViews
      @formattedOutputView = views.formattedOutputView
      Logger.log("Controller.connectToSidebarViews()", @sidebarView, @formattedOutputView)


    connectToConsoleViews: (views) =>
      @consoleViews = views
      Logger.log("Controller.connectToConsoleViews()")


    addIconsToConsoleTabs: =>
      Logger.log("Controller.addIconsToConsoleTabs()")
      viewTabs = document.querySelectorAll(".tab[data-type=FlexiblePanelView]")
      Logger.log(viewTabs);
      viewTabs.forEach((tab) ->
        switch tab.children[0].innerHTML
          when "Log" then tab.classList.add "logViewTab"
          when "Warnings" then tab.classList.add "warningsTab"
          when "Errors (TeSSLa)" then tab.classList.add "errorsTeSSLaTab"
          when "Errors (C)" then tab.classList.add "errorsCTab"
          when "Console" then tab.classList.add "consoleTab"
      )


    onPullLatestImage: =>
      @lockAllButtons()
      if isSet(@runningProcess) or @currentlyMounting
        @unlockAllButtons()
        return
      Logger.log("Pull latest TeSSLa image")
      new DockerMediator().pull().then((log) =>
        for item in log
          if item.type is "entry"
            @consoleViews.logView.addEntry([item.label, item.msg])
          if item.type is "listEntry"
            @consoleViews.logView.addListEntry(item.title, [item.label, item.msg])
        @unlockAllButtons()
        @mountProjectIntoContainer().catch((err) =>
          Logger.err(err)
        )
      )


    onStartContainer: =>
      @lockAllButtons()
      if isSet(@runningProcess) or @currentlyMounting
        @unlockAllButtons()
        return
      @unlockAllButtons()
      @mountProjectIntoContainer().catch((err) =>
        Logger.log(err)
      )


    restoreViews: =>
      @lockAllButtons()
      Logger.log("Controller.restoreViews()")
      Promise.all([
        atom.workspace.open @consoleViews.consoleView.getURI()
        atom.workspace.open @consoleViews.errorsCView.getURI()
        atom.workspace.open @consoleViews.errorsTeSSLaView.getURI()
        atom.workspace.open @consoleViews.warningsView.getURI()
        atom.workspace.open @consoleViews.logView.getURI()
        atom.workspace.open FORMATTED_OUTPUT_VIEW
        atom.workspace.open SIDEBAR_VIEW
      ]).then((views) =>
        viewsContainer = {}
        for view in views
          unless view?.getURI() is FORMATTED_OUTPUT_VIEW or view?.getURI() is SIDEBAR_VIEW
            switch view?.getTitle()
              when "Console" then viewsContainer.consoleView = view
              when "Errors (C)" then viewsContainer.errorsCView = view
              when "Errors (TeSSLa)" then viewsContainer.errorsTeSSLaView = view
              when "Warnings" then viewsContainer.warningsView = view
              when "Log" then viewsContainer.logView = view
              else Logger.log(view)
          else
            viewsContainer.sidebarViews = view if view.getURI() is SIDEBAR_VIEW
            viewsContainer.formattedOutputView = view if view.getURI() is FORMATTED_OUTPUT_VIEW
            viewsContainer.unknown.push view unless viewsContainer.formattedOutputView? or viewsContainer.formattedOutputView
        for key, value of viewsContainer
          @consoleViews.key = value if @consoleViews.key?
        @addIconsToConsoleTabs()
        @unlockAllButtons()
      ).catch((err) =>
        @unlockAllButtons()
        Logger.err(err);
      )


    setUpSplitView: =>
      @lockAllButtons()
      Logger.log("Controller.setUpSplitView()");
      projPath = @activeProject.getPath()
      allow = { dotfolders: yes, dotfiles: yes, modules: yes }
      cFiles = scanFolder(@activeProject.getPath(), ".c", yes, allow)
      tesslaFiles = scanFolder(@activeProject.getPath(), ".tessla", yes, allow)

      if cFiles is null or cFiles is undefined or cFiles.length is 0 or tesslaFiles is null or tesslaFiles is undefined or tesslaFiles.length is 0
        message = "There are no \".tessla\" and \".c\" files to put into split view in the current project. Please open at least one file of your project and activate it in workspace to properly set up the split view. The split view can be set up by right click onto your source file in the text editor and select \"Set up TeSSLa split view\" in the context menu."
        atom.notifications.addWarning("Could not set up the split view", {
          detail: message
        })
        @consoleViews.warningsView.addEntry([message])
        return

      # clean up existing workspace
      for item in atom.workspace.getCenter().getPaneItems()
        item.destroy()

      # create split view
      chain = atom.workspace.open(cFiles[0], { split: "left" })
      chain = chain.then(() => atom.workspace.open(tesslaFiles[0], { split: "right" }))
      chain.then(() =>
        # open other c files
        for file in cFiles
          atom.workspace.open(file, { split: "left", location: "center" })
        # open other tessla files
        for i in [1...tesslaFiles.length]
          file = tesslaFiles[i]
          atom.workspace.open(file, { split: "right" })
      )
      @unlockAllButtons()


    mountProjectIntoContainer: =>
      return new Promise((resolve, reject) =>
        Logger.log("Controller.mountProjectIntoContainer()")
        notification = @showIndeterminateProgress(
          "Creating TeSSLa-Container...",
          "Creating a Docker TeSSLa-Container and mount \"#{@activeProject.getPath()}\" into container. This may take a few seconds.",
          no
        )
        @lockAllButtons()
        @currentlyMounting = yes
        if @validActiveProject()
          mediator = new DockerMediator
          mediator.isDockerDaemonRunning()
          .then(=> mediator.startTeSSLaContainer(@activeProject.getPath()))
          .then((logs) =>
            for log in logs
              @consoleViews.logView.addEntry(log)
            notification.dismiss()
            @unlockAllButtons()
            @currentlyMounting = no
            resolve()
          ).catch((err) =>
            notification.dismiss()
            @unlockAllButtons()
            @currentlyMounting = no
            reject(err)
          )
        else
          reject(new Error("Project is broken."))
      )


    checkActiveTargetForTeSSLa: =>
      return new Promise((resolve, reject) =>
        Logger.log("Controller.checkActiveTargetForTeSSLa()")
        @activeProject.readTarget().then((target) =>
          if not isSet(target)
            reject(new Error("No target is specified in \"targets.yml\""))
          if not isSet(target.tessla)
            reject(new Error("No TeSSLa specification found in the active target"))
          resolve()
        ).catch((err) =>
          reject(err)
        )
      )


    checkActiveTargetForInput: =>
      return new Promise((resolve, reject) =>
        Logger.log("Controller.checkActiveTargetForInput()")
        @activeProject.readTarget().then((target) =>
          if not isSet(target)
            reject(new Error("No target is specified in \"targets.yml\""))
          if not isSet(target.input)
            reject(new Error("No trace input found in the active target"))
          if isSet(target.input) and isSet(target.c)
            reject(new Error("Trace input and C sources specified in the active target. Please use only one of both."))
          resolve()
        ).catch((err) =>
          reject(err)
        )
      )


    checkActiveTargetForC: =>
      return new Promise((resolve, reject) =>
        Logger.log("Controller.checkActiveTargetForInput()")
        @activeProject.readTarget().then((target) =>
          if not isSet(target)
            reject(new Error("No target is specified in \"targets.yml\""))
          if not isSet(target.c)
            reject(new Error("No C sources found in the active target"))
          if isSet(target.input) and isSet(target.c)
            reject(new Error("Trace input and C sources specified in the active target. Please use only one of both."))
          resolve()
        ).catch((err) =>
          reject(err)
        )
      )


    checkActiveTargetForCOrInput: =>
      return new Promise((resolve, reject) =>
        Logger.log("Controller.checkActiveTargetForInput()")
        @activeProject.readTarget().then((target) =>
          if not isSet(target)
            reject(new Error("No target is specified in \"targets.yml\""))
          if not isSet(target.c) and not isSet(target.input)
            reject(new Error("No C sources or trace input found in the active target"))
          if isSet(target.input) and isSet(target.c)
            reject(new Error("Trace input and C sources specified in the active target. Please use only one of both."))
          resolve()
        ).catch((err) =>
          reject(err)
        )
      )


    validActiveProject: =>
      Logger.log("Controller.validActiveProject()")
      if not isSet(@activeProject)
        message = "There is currently no active project in your workspace."
        atom.notifications.addWarning("Could not create trace file", {
          detail: message
        })
        @consoleViews.warningsView.addEntry([message])
        return no
      projPath = @activeProject.getPath()
      if not isSet(projPath) or projPath is ""
        message = "Your project has no correct path on your disk. Found path was \"\"."
        atom.notifications.addWarning("Could not create trace file", {
          detail: message
        })
        @consoleViews.warningsView.addEntry([message])
        return no
      return yes


    noProcessRunning: =>
      return new Promise((resolve, reject) =>
        if @currentlyMounting
          message = "You can not start process until the docker container is properly connected to the current project."
          # atom.notifications.addWarning("Could start process", {
          #   detail: message
          # })
          # @consoleViews.warningsView.addEntry([message])
          reject(new Error(message))
        else if isSet(@runningProcess)
          message = "You can not start another process if there is another process in execution."
          # atom.notifications.addWarning("Could start process", {
          #   detail: message
          # })
          # @consoleViews.warningsView.addEntry([message])
          reject(new Error("There is already a process in execution!"))
        else
          resolve()
      )


    lockButtons: =>
      Logger.log("Controller.lockButtons()")
      if isSet(@toolbarButtons)
        @toolbarButtons.CreateTrace.setEnabled(no)
        @toolbarButtons.BuildAndRunCCode.setEnabled(no)
        @toolbarButtons.BuildAndRunProject.setEnabled(no)
        @toolbarButtons.StartContainer.setEnabled(no)
        @toolbarButtons.PullImage.setEnabled(no)
        @toolbarButtons.Stop.setEnabled(yes)


    lockAllButtons: =>
      Logger.log("Controller.lockAllButtons()")
      if isSet(@toolbarButtons)
        @toolbarButtons.CreateTrace.setEnabled(no)
        @toolbarButtons.BuildAndRunCCode.setEnabled(no)
        @toolbarButtons.BuildAndRunProject.setEnabled(no)
        @toolbarButtons.StartContainer.setEnabled(no)
        @toolbarButtons.PullImage.setEnabled(no)
        @toolbarButtons.Stop.setEnabled(no)
        @toolbarButtons.SplitView.setEnabled(no)
        @toolbarButtons.ResetViews.setEnabled(no)


    unlockButtons: =>
      Logger.log("Controller.unlockButtons()")
      if isSet(@toolbarButtons)
        @toolbarButtons.CreateTrace.setEnabled(yes)
        @toolbarButtons.BuildAndRunCCode.setEnabled(yes)
        @toolbarButtons.BuildAndRunProject.setEnabled(yes)
        @toolbarButtons.StartContainer.setEnabled(yes)
        @toolbarButtons.PullImage.setEnabled(yes)
        @toolbarButtons.Stop.setEnabled(no)

    unlockAllButtons: =>
      Logger.log("Controller.unlockAllButtons()")
      if isSet(@toolbarButtons)
        @toolbarButtons.CreateTrace.setEnabled(yes)
        @toolbarButtons.BuildAndRunCCode.setEnabled(yes)
        @toolbarButtons.BuildAndRunProject.setEnabled(yes)
        @toolbarButtons.StartContainer.setEnabled(yes)
        @toolbarButtons.PullImage.setEnabled(yes)
        @toolbarButtons.Stop.setEnabled(yes)
        @toolbarButtons.SplitView.setEnabled(yes)
        @toolbarButtons.ResetViews.setEnabled(yes)


    onCreateTrace: =>
      mediator = new DockerMediator
      @noProcessRunning().then(=>
        return mediator.isTeSSLaContainerRunning()
      ).then((running) =>
        if not running
          return @mountProjectIntoContainer()
        else
          return new Promise((resolve, reject) => resolve())
      ).then(=>
        return @checkActiveTargetForC()
      ).then(=>
        return @activeProject.readTarget()
      ).then((target) =>
        # Get information about c and spec file
        if not isSet(target.c)
          message = "There are no C sources specified for this target. Only valid C programs can be instrumented!"
          atom.notifications.addError("Could not create trace file", {
            detail: message
          })
          @consoleViews.logView.addEntry(["message", message])
          @consoleViews.errorsTeSSLaView.addEntry([message])
          return
        # information about the file to create
        hadError = no
        traceName = "#{target.binName}.input"
        traceFile = fs.createWriteStream(path.join(@activeProject.getPath(), traceName), { flags: "w" })
        traceContent = []
        # exec command
        dockerArgs = ["exec", TESSLA_CONTAINER_NAME, "tessla_rv"]
        for file in target.c
          dockerArgs.push(file)
        notification = @showIndeterminateProgress("Instrumenting C Sources", "Creating trace file \"#{path.join(@activeProject.getPath(), traceName)}\"")
        @lockButtons()
        @runningProcess = tessla = childProcess.spawn("docker", dockerArgs)
        @consoleViews.logView.addEntry(["Docker", "docker #{dockerArgs.join(" ")}"])
        # listen on output stream
        tessla.stdout.on("data", (data) =>
          lines = data.toString()
          for line in lines.split("\n").filter((l) => l isnt "")
            if line.startsWith("[binary]")
              @consoleViews.consoleView.addEntry([line.replace(/\[(binary)\]\s*/g, "")])
            else if line.startsWith("[trace ]")
              prepared = line.replace(/\[trace \]\s*/g, "")
              @consoleViews.consoleView.addEntry([prepared])
              traceFile.write("#{prepared}\n", "utf-8")
              traceContent.push(prepared)
        )
        # listen on error stream
        tessla.stderr.on("data", (data) =>
          line = data.toString()
          if line.startsWith("[status]")
            @consoleViews.logView.addEntry(["TeSSLa RV", line.replace(/\[status\]\s*/g, "")])
          else
            hadError = yes
            @consoleViews.errorsTeSSLaView.addEntry([line])
        )
        # act if everything is done
        tessla.on("close", (code, signal) =>
          @runningProcess = null
          @unlockButtons()
          notification.dismiss()
          if hadError
            message = "An error occurred. See \"Errors (TeSSLa)\" view for further information"
            atom.notifications.addError("Could not create trace file", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", message])
          else if signal is "SIGKILL"
            message = "Process was stopped manually"
            atom.notifications.addError("Could not create trace file", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", message])
          else
            atom.notifications.addSuccess("Trace \"#{path.join(@activeProject.getPath(), traceName)}\" created", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", "Trace \"#{path.join(@activeProject.getPath(), traceName)}\" created"])
            @formattedOutputView.update(traceContent)
        )
      ).catch((err) =>
        message = err.message
        atom.notifications.addError("Could not create trace file", { detail: message })
        @consoleViews.logView.addEntry(["message", message])
        Logger.err(err)
      )


    onCompileAndRunCCode: =>
      Logger.log("Controller.onCompileAndRunCCode()")
      mediator = new DockerMediator
      @noProcessRunning().then(=>
        return mediator.isTeSSLaContainerRunning()
      ).then((running) =>
        if not running
          return @mountProjectIntoContainer()
        else
          return new Promise((resolve, reject) => resolve())
      ).then(=>
        return @checkActiveTargetForC()
      ).then(=>
        return @activeProject.readTarget()
      ).then((target) =>
        # Get information about c and spec file
        if not isSet(target.c)
          message = "Target does not specifie C sources to compile and execute!"
          atom.notifications.addError("Could not compile and run C code", {
            detail: message
          })
          @consoleViews.logView.addEntry(["message", message])
          @consoleViews.errorsCView.addEntry([message])
          return
        hadError = no
        # exec command
        dockerArgs = [
          "exec",
          TESSLA_CONTAINER_NAME,
          "clang",
          "-o",
          path.join("bin", target.binName)
        ]
        for file in target.c
          dockerArgs.push(file)
        notification = @showIndeterminateProgress("Coameling C Sources", "Compiling C source files: #{target.c.map((file) => "\"#{file}\"").join(" ")}")
        @lockButtons()
        @runningProcess = compile = childProcess.spawn("docker", dockerArgs)
        compile.stderr.on("data", (data) =>
          hadError = yes
          @consoleViews.errorsCView.addEntry([data.toString()])
        )
        @consoleViews.logView.addEntry(["Docker", "docker #{dockerArgs.join(" ")}"])
        compile.on("close", (code, signal) =>
          @runningProcess = null
          @unlockButtons()
          notification.dismiss()
          if hadError
            message = "An error occurred. See \"Errors (C)\" view for further information"
            atom.notifications.addError("Could not compile C sources", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", message])
          else if signal is "SIGKILL"
            message = "Process was stopped manually"
            atom.notifications.addError("Could not compile C sources", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", message])
          else
            hadError = no
            dockerArgs = ["exec", TESSLA_CONTAINER_NAME, path.join("bin", target.binName)]
            notification = @showIndeterminateProgress("Executing binary", "Executing binary: \"#{path.join("bin", target.binName)}\"")
            @lockButtons()
            @runningProcess = program = childProcess.spawn("docker", dockerArgs)
            program.stdout.on("data", (data) =>
              output = data.toString().split("\n")
              for line in output
                @consoleViews.consoleView.addEntry([line])
            )
            program.stderr.on("data", (data) =>
              hadError = yes
              @consoleViews.errorsCView.addEntry([data.toString()])
            )
            program.on("close", (code, signal) =>
              @runningProcess = null
              @unlockButtons()
              notification.dismiss()
              if hadError
                message = "An error occurred. See \"Errors (C)\" view for further information"
                atom.notifications.addError("Could not execute C binary", {
                  detail: message
                })
                @consoleViews.logView.addEntry(["message", message])
              else if signal is "SIGKILL"
                message = "Process was stopped manually"
                atom.notifications.addError("Could not execute binary", {
                  detail: message
                })
                @consoleViews.logView.addEntry(["message", message])
              else
                message = "Compiled and executed C sources"
                atom.notifications.addSuccess(message, {
                  detail: message
                })
                @consoleViews.logView.addEntry(["message", message])
            )
        )
      ).catch((err) =>
        message = err.message
        atom.notifications.addError("Could not compile and execute C sources", { detail: message })
        @consoleViews.logView.addEntry(["message", message])
        Logger.err(err)
      )


    onCompileAndRunProject: =>
      Logger.log("Controller.onCompileAndRunProject()")
      mediator = new DockerMediator
      @noProcessRunning().then(=>
        return mediator.isTeSSLaContainerRunning()
      ).then((running) =>
        if not running
          return @mountProjectIntoContainer()
        else
          return new Promise((resolve, reject) => resolve())
      ).then(=>
        return @checkActiveTargetForTeSSLa()
      ).then(=>
        return @checkActiveTargetForCOrInput()
      ).then(=>
        return @activeProject.readTarget()
      ).then((target) =>
        # Get information about c and spec file
        hadError = no
        dockerArgs = ["exec", TESSLA_CONTAINER_NAME]
        if isSet(target.c)
          dockerArgs = dockerArgs.concat(["tessla_rv", "--spec", target.tessla])
          for file in target.c
            dockerArgs.push(file)
        else
          dockerArgs = dockerArgs.concat(["tessla", target.tessla, target.input])
        traceContent = []
        notification = @showIndeterminateProgress("Verify Project Files", "Verifying project files using \"#{target.tessla}\"")
        @lockButtons()
        @runningProcess = rv = childProcess.spawn("docker", dockerArgs)
        rv.stderr.on("data", (data) =>
          line = data.toString()
          if line.startsWith("[status]")
            @consoleViews.logView.addEntry(["TeSSLa RV", line.replace(/\[status\]\s*/g, "")])
          else if line.startsWith("[clang ]")
            hadError = yes
            @consoleViews.errorsTeSSLaView.addEntry([line.replace(/\[clang \]\s*/g, "")])
          else
            hadError = yes
            @consoleViews.errorsTeSSLaView.addEntry([line])
        )
        rv.stdout.on("data", (data) =>
          lines = data.toString()
          for line in lines.split("\n").filter((l) => l isnt "")
            if line.startsWith("[binary]")
              @consoleViews.consoleView.addEntry([line.replace(/\[(binary)\]\s*/g, "")])
            else if line.startsWith("[tessla]")
              prepared = line.replace(/\[tessla\]\s*/g, "")
              @consoleViews.consoleView.addEntry([prepared])
              traceContent.push(prepared)
            else
              @consoleViews.consoleView.addEntry([line])
              traceContent.push(line)
        )
        @consoleViews.logView.addEntry(["Docker", "docker #{dockerArgs.join(" ")}"])
        rv.on("close", (code, signal) =>
          @runningProcess = null
          @unlockButtons()
          notification.dismiss()
          if hadError
            message = "An error occurred during project verification. For further information see \"Errors (TeSSLa)\" view."
            atom.notifications.addError("Could not verify project by TeSSLa specification", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", message])
          else if signal is "SIGKILL"
            message = "Process was stopped manually"
            atom.notifications.addError("Could not verify project files", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", message])
          else
            atom.notifications.addSuccess("Verified project files", {
              detail: message
            })
            @consoleViews.logView.addEntry(["message", "Verified project files"])
            @formattedOutputView.update(traceContent)
        )
      ).catch((err) =>
        message = err.message
        atom.notifications.addError("Could not verify project files", { detail: message })
        @consoleViews.logView.addEntry(["message", message])
        Logger.err(err)
      )


    onStopRunningProcess: =>
      if @runningProcess isnt null
        @runningProcess.kill("SIGKILL")
        @consoleViews.logView.addEntry(["command", "kill -9 #{@runningProcess.pid}"])


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

    dispose: ->
      @subscriptions.dispose()
