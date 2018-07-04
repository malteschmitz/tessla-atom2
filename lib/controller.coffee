path = require "path"
childProcess = require "child_process"
fs = require "fs-extra"
os = require "os"
Docker = require "dockerode"
docker = new Docker

FileManager = require "./file-manager"
SourceHighlighter = require "./source-highlighter"
Downloader = require "./downloader"
MessageQueue = require "./message-queue"
{TESSLA_REGISTRY, TESSLA_IMAGE_NAME, TESSLA_CONTAINER_NAME} = require "./constants"

module.exports=
  class Controller
    constructor: (@viewManager) ->
      @runningProcess = null
      @containerDir = path.join os.homedir(), ".tessla-env"
      @containerBuild = path.join @containerDir, "bin"
      @SourceHighlighter = new SourceHighlighter
      @messageQueue = new MessageQueue @viewManager
      @initiallyPulled = no


    onViewSetUpReady: ->
      @messageQueue.flush()


    onCompileAndRunCCode: ->
      # if there is not a current project stop further exectution
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
      # if there is already a process running stop further exectution
      else if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
      # if everything is OK try to compile and run C-Code
      else
        # save editors and start compiliation and execution process
        @viewManager.saveEditors()
        # check if the Docker daemon is still running
        # check if the Docker daemon is still running
        @isDockerDaemonRunning
          # Docker daemon not running
          ifNot: =>
            # show notification to user
            message = "The Docker daemon does not respond. Maybe Docker is not running? The TeSSLa2 Package could not be started since it depends on Docker. Please check your Docker installation and try again later."
            atom.notifications.addError "Docker daemon does not respond.",
              detail: message
            @messageQueue.enqueueEntries { type: "entry", title: "", label: "message", msg: message }
            @messageQueue.flush()
          ifYes: =>
            # define a variable which defines the process behavior
            compileAndRun = () => @onBuildCCode onSuccess: -> @onRunBinary()
            # define the process as a function to not copy and paste the whole
            # stuff twice into the if-else case below
            verification = () =>
              # check if container is still running
              @isDockerContainerRunning
                # if the docker container is also running everything is fine and we
                # can start doing RV
                ifYes: => compileAndRun()
                # if container is not running try to do the setup again
                ifNot: => @isTeSSLaEnvExisting
                  # if the env directory is existing we can directly start the
                  # docker container itself and the do RV
                  ifYes: => @startDockerContainer => compileAndRun()
                  # if the .tessla-env directory does not exist create it start
                  # a container and then do RV
                  ifNot: => @createTeSSLaEnv => @startDockerContainer => compileAndRun()
            # check if there was an initial docker pull
            if not @initiallyPulled
              # first pull and then try the RV stuff
              @dockerPull => verification()
            else
              # if ther was already an initial docker pull just try the RV stuff
              verification()


    onCreateTraceFile: ->
      # if there is no current Project stop further execution
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
      # if there is already a process running stop further execution
      else if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
      # if everything is OK try to start verification process
      else
        # save editors and start compilation and instrumenting process
        @viewManager.saveEditors()
        # check if the Docker daemon is still running
        @isDockerDaemonRunning
          # Docker daemon not running
          ifNot: =>
            # show notification to user
            message = "The Docker daemon does not respond. Maybe Docker is not running? The TeSSLa2 Package could not be started since it depends on Docker. Please check your Docker installation and try again later."
            atom.notifications.addError "Docker daemon does not respond.",
              detail: message
            @messageQueue.enqueueEntries { type: "entry", title: "", label: "message", msg: message }
            @messageQueue.flush()
          # Docker daemon is running
          ifYes: =>
            # define the process as a function to not copy and paste the whole
            # stuff twice into the if-else case below
            verification = () =>
              # check if container is still running
              @isDockerContainerRunning
                # if the docker container is also running everything is fine and we
                # can start doing RV
                ifYes: => onCreateTrace()
                # if container is not running try to do the setup again
                ifNot: => @isTeSSLaEnvExisting
                  # if the env directory is existing we can directly start the
                  # docker container itself and the do RV
                  ifYes: => @startDockerContainer => onCreateTrace()
                  # if the .tessla-env directory does not exist create it start
                  # a container and then do RV
                  ifNot: => @createTeSSLaEnv => @startDockerContainer => onCreateTrace()
            # check if there was an initial docker pull
            if not @initiallyPulled
              # first pull and then try the RV stuff
              @dockerPull => verification()
            else
              # if there was already an initial docker pull just try the RV stuff
              verification()


    onCompileAndRunProject: ->
      # if there is no current Project stop further execution
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
      # if there is already a process running stop further execution
      else if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
      # if everything is OK try to start verification process
      else
        # save editors and start compilation and instrumenting process
        @viewManager.saveEditors()
        # check if the Docker daemon is still running
        @isDockerDaemonRunning
          # Docker daemon not running
          ifNot: =>
            # show notification to user
            message = "The Docker daemon does not respond. Maybe Docker is not running? The TeSSLa2 Package could not be started since it depends on Docker. Please check your Docker installation and try again later."
            atom.notifications.addError "Docker daemon does not respond.",
              detail: message
            @messageQueue.enqueueEntries { type: "entry", title: "", label: "message", msg: message }
            @messageQueue.flush()
          # Docker daemon is running
          ifYes: =>
            # define a variable containing the doRV stuff
            doRV = (notification) =>
              @onDoRV
                onSuccess: (lines) ->
                  notification.dismiss()
                  @viewManager.showSuccessfullyInstrumentedNotification()
                  @viewManager.views.formattedOutputView.update lines
                onError: (errs) ->
                  notification.dismiss()
                  for error in errs
                    @viewManager.views.errorsTeSSLaView.addEntry [error]
            # define the process as a function to not copy and paste the whole
            # stuff twice into the if-else case below
            verification = () =>
              # show a notification with a indeterminate progress to show something is
              # happening
              notification = @viewManager.showIndeterminateProgress(
                "Compiling/Instrumenting",
                "Compiling and instrumenting project files using the TeSSLa2 Docker-container. For further information see \"Console\"/\"Log\" view."
              )
              # check if container is still running
              @isDockerContainerRunning
                # if the docker container is also running everything is fine and we
                # can start doing RV
                ifYes: => doRV(notification)
                # if container is not running try to do the setup again
                ifNot: => @isTeSSLaEnvExisting
                  # if the env directory is existing we can directly start the
                  # docker container itself and the do RV
                  ifYes: => @startDockerContainer => doRV(notification)
                  # if the .tessla-env directory does not exist create it start
                  # a container and then do RV
                  ifNot: => @createTeSSLaEnv => @startDockerContainer => doRV(notification)
            # check if there was an initial docker pull
            if not @initiallyPulled
              # first pull and then try the RV stuff
              @dockerPull => verification()
            else
              # if there was already an initial docker pull just try the RV stuff
              verification()


    onRunProjectByTrace: () ->
      console.log("run project by trace file");
      # if there is no current Project stop further execution
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
      # if there is already a process running stop further execution
      else if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
      # if everything is OK try to start verification process
      else
        # save editors and start compilation and instrumenting process
        @viewManager.saveEditors()
        # check if the Docker daemon is still running
        @isDockerDaemonRunning
          # Docker daemon not running
          ifNot: =>
            # show notification to user
            message = "The Docker daemon does not respond. Maybe Docker is not running? The TeSSLa2 Package could not be started since it depends on Docker. Please check your Docker installation and try again later."
            atom.notifications.addError "Docker daemon does not respond.",
              detail: message
            @messageQueue.enqueueEntries { type: "entry", title: "", label: "message", msg: message }
            @messageQueue.flush()
          # Docker daemon is running
          ifYes: =>
            # define a variable containing the doRV stuff
            doRV = (notification) =>
              @onDoRVOnTrace
                onSuccess: (lines) ->
                  notification.dismiss()
                  @viewManager.showSuccessfullyInstrumentedNotification()
                  @viewManager.views.formattedOutputView.update lines
                onError: (errs) ->
                  notification.dismiss()
                  for error in errs
                    @viewManager.views.errorsTeSSLaView.addEntry [error]
            # define the process as a function to not copy and paste the whole
            # stuff twice into the if-else case below
            verification = () =>
              # show a notification with a indeterminate progress to show something is
              # happening
              notification = @viewManager.showIndeterminateProgress(
                "Instrumenting trace file",
                "Instrumenting trace file using the TeSSLa2 Docker-container. For further information see \"Console\"/\"Log\" view."
              )
              # check if container is still running
              @isDockerContainerRunning
                # if the docker container is also running everything is fine and we
                # can start doing RV
                ifYes: => doRV(notification)
                # if container is not running try to do the setup again
                ifNot: => @isTeSSLaEnvExisting
                  # if the env directory is existing we can directly start the
                  # docker container itself and the do RV
                  ifYes: => @startDockerContainer => doRV(notification)
                  # if the .tessla-env directory does not exist create it start
                  # a container and then do RV
                  ifNot: => @createTeSSLaEnv => @startDockerContainer => doRV(notification)
            # check if there was an initial docker pull
            if not @initiallyPulled
              # first pull and then try the RV stuff
              @dockerPull => verification()
            else
              # if there was already an initial docker pull just try the RV stuff
              verification()


    onCreateTrace: () ->
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        return

      unless @viewManager.activeProject.cFiles?
        @viewManager.showNoCompilableCFilesNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      @transferFilesToContainer()

      traceFile = path.join @viewManager.activeProject.projPath, "#{@viewManager.activeProject.binName}.trace"
      # fs.closeSync(fs.openSync(traceFile, "w"));

      cFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.cFiles[0]
      args = ["exec", TESSLA_CONTAINER_NAME, "tessla_rv", "#{cFile}"]

      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", command]

      errors = []
      outputs = []
      trace = []
      @runningProcess.stdout.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        for line in lines
          @filterScriptOutput line, true, errors, outputs, trace

      @runningProcess.stderr.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        for line in lines
          @filterScriptOutput line, false, errors, outputs, trace

      @runningProcess.on "close", (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry ["<strong>Process exited with code #{code}.</strong>"]  if code?
        @viewManager.views.consoleView.addEntry ["<strong>Process was killed due to signal #{signal}.</strong>"]  if signal?

        # console.log errors
        if trace.length isnt 0
          fs.writeFileSync(traceFile, trace.join("\n") + "\n");
          @viewManager.views.logView.addEntry ["message", "Successfully created trace file"]
          atom.notifications.addSuccess "Successfully created trace file"

        else if code? and code isnt 0
          @viewManager.views.logView.addEntry ["message", "An error occurred while creating a trace file."]
          atom.notifications.addError "Errors while creating trace file",
            detail: errors.join ""
          errors.push "Errors while creating trace file"

        else if signal?
          @viewManager.views.logView.addEntry ["message", "An error occurred while creating a trace file. The process was killed due to signal #{signal}"]
          atom.notifications.addError "Errors while creating trace file. Process was killed due to signal #{signal}.",
            detail: errors.join ""
          errors.push "Errors while creating trace file. Process was killed due to signal #{signal}."


    onBuildCCode: ({ onSuccess, onError }) ->
      successCallback = if onSuccess? then onSuccess else () -> {}
      errorCallback = if onError? then onError else () -> {}

      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        return

      unless @viewManager.activeProject.cFiles?
        @viewManager.showNoCompilableCFilesNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      @transferFilesToContainer()

      outFile = path.join "bin", @viewManager.activeProject.binName

      args = ["exec", TESSLA_CONTAINER_NAME, "clang", "-o", outFile]
      args = args.concat @viewManager.activeProject.cFiles.map (arg) =>
        path.relative @viewManager.activeProject.projPath, arg .replace /\\/g, "/"

      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", command]

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        outputs.push data.toString()
        # console.log data.toString()

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsCView.addEntry [data.toString()]
        errors.push data.toString()

      @runningProcess.on "close", () =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        if errors.length is 0
          @viewManager.views.logView.addEntry ["message", "Successfully compiled C sources."]
          atom.notifications.addSuccess "Successfully compiled C files"
          successCallback.call @

        else
          @viewManager.views.logView.addEntry ["message", "An error occurred while compiling C sources."]
          atom.notifications.addError "Errors while compiling C files",
            detail: errors.join ""
          errorCallback.call @


    onRunBinary: ->
      unless @viewManager.activeProject.projPath?
        @viewManager.showNoProjectNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      args = ["exec",  TESSLA_CONTAINER_NAME, "./bin/#{@viewManager.activeProject.binName}"]

      @runningProcess = childProcess.spawn "docker", args

      binary = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", binary]

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        @viewManager.views.consoleView.addEntry [data.toString()]
        outputs.push data.toString()

      errors = []
      @runningProcess.stderr.on 'data', (data) =>
        @viewManager.views.errorsCView.addEntry [data.toString()]
        errors.push data.toString()

      @runningProcess.on 'close', (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry ["<strong>Process exited with code #{code}.</strong>"]  if code?
        @viewManager.views.consoleView.addEntry ["<strong>Process was killed due to signal #{signal}.</strong>"]  if signal?

        if errors.length isnt 0
          @viewManager.views.logView.addEntry ["message", "An error occurred while running C binary"]
          atom.notifications.addError "Errors while running the C binary",
            detail: errors.join ""


    filterScriptOutput: (line, stdout, errors, outputs, trace = []) ->
      prefix = line.substr(0, 8)
      suffix = line.substr(8).trim()

      switch prefix
        when "[status]"
          @viewManager.views.logView.addEntry ["status", suffix]
        when "[clang ]"
          @viewManager.views.errorsCView.addEntry [suffix]
          errors.push suffix
        when "[ld    ]"
          @viewManager.views.errorsCView.addEntry [suffix]
          errors.push suffix
        when "[trace ]"
          # @viewManager.views.errorsTeSSLaView.addEntry [suffix]
          # errors.push suffix
          trace.push suffix
        when "[tessla]"
          if stdout
            @viewManager.views.consoleView.addEntry [suffix]
            outputs.push suffix
          else
            @viewManager.views.errorsTeSSLaView.addEntry [suffix]
            errors.push suffix
        when "[instr ]"
          @viewManager.views.consoleView.addEntry [suffix]
          outputs.push suffix
        when "[binary]"
          @viewManager.views.consoleView.addEntry [suffix]
          outputs.push suffix
        else
          @viewManager.views.errorsTeSSLaView.addEntry [line]
          errors.push line


    onDoRVOnTrace: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        errorCallback.call @, []
        return

      console.log(@viewManager.activeProject.traceFiles);

      unless @viewManager.activeProject.traceFiles?
        @viewManager.showNoCompilableTraceFilesNotification()
        errorCallback.call @, []
        return

      unless @viewManager.activeProject.tesslaFiles?
        @viewManager.showNoCompilableTeSSLaFilesNotification()
        errorCallback.call @, []
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        errorCallback.call @, []
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      @transferFilesToContainer()

      trcFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.traceFiles[0]
      tsslFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.tesslaFiles[0]

      args = ["exec", TESSLA_CONTAINER_NAME, "tessla", "#{tsslFile}", "#{trcFile}"]

      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", command]

      errors = []
      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        for line in lines
          @filterScriptOutput line, true, errors, outputs

      @runningProcess.stderr.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        for line in lines
          @filterScriptOutput line, false, errors, outputs

      @runningProcess.on "close", (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry ["<strong>Process exited with code #{code}.</strong>"]  if code?
        @viewManager.views.consoleView.addEntry ["<strong>Process was killed due to signal #{signal}.</strong>"]  if signal?

        # console.log errors

        if errors.length is 0 and (code is 0) and not (signal?)
          # @viewManager.views.logView.addEntry ["message", "Successfully compiled C sources"]
          # atom.notifications.addSuccess "Successfully compiled C sources"
          successCallback.call @, outputs

        else if code? and code isnt 0
          @viewManager.views.logView.addEntry ["message", "An error occurred while instrumenting the trace file."]
          atom.notifications.addError "Errors while instrumenting trace file",
            detail: errors.join ""
          errors.push "Errors while instrumenting trace file"
          errorCallback.call @, errors

        else if signal?
          @viewManager.views.logView.addEntry ["message", "An error occurred while instrumenting the trace file. The process was killed due to signal #{signal}"]
          atom.notifications.addError "Errors while instrumenting trace file Process was killed due to signal #{signal}.",
            detail: errors.join ""
          errors.push "Errors while instrumenting trace file Process was killed due to signal #{signal}."
          errorCallback.call @, errors


    onDoRV: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      # console.log "[TeSSLa2][debug] controller.coffee:196: Compile project", @viewManager.activeProject.projPath

      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        errorCallback.call @, []
        return

      # console.log "[TeSSLa2][debug] controller.coffee:196: Compile project", @viewManager.activeProject.cFiles, @viewManager.activeProject.cFiles?
      unless @viewManager.activeProject.cFiles?
        @viewManager.showNoCompilableCFilesNotification()
        errorCallback.call @, []
        return

      unless @viewManager.activeProject.tesslaFiles?
        @viewManager.showNoCompilableTeSSLaFilesNotification()
        errorCallback.call @, []
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        errorCallback.call @, []
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      @transferFilesToContainer()

      cFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.cFiles[0]
      tsslFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.tesslaFiles[0]

      args = ["exec", TESSLA_CONTAINER_NAME, "tessla_rv", "#{cFile}", "#{tsslFile}"]

      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", command]

      errors = []
      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        for line in lines
          @filterScriptOutput line, true, errors, outputs

      @runningProcess.stderr.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        for line in lines
          @filterScriptOutput line, false, errors, outputs

      @runningProcess.on "close", (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry ["<strong>Process exited with code #{code}.</strong>"]  if code?
        @viewManager.views.consoleView.addEntry ["<strong>Process was killed due to signal #{signal}.</strong>"]  if signal?

        # console.log errors

        if errors.length is 0 and (code is 0) and not (signal?)
          # @viewManager.views.logView.addEntry ["message", "Successfully compiled C sources"]
          # atom.notifications.addSuccess "Successfully compiled C sources"
          successCallback.call @, outputs

        else if code? and code isnt 0
          @viewManager.views.logView.addEntry ["message", "An error occurred while compiling or instrumenting project files"]
          atom.notifications.addError "Errors while compiling and instrumenting project files",
            detail: errors.join ""
          errors.push "Errors while compiling and instrumenting project files"
          errorCallback.call @, errors

        else if signal?
          @viewManager.views.logView.addEntry ["message", "An error occurred while instrumenting project files. The process was killed due to signal #{signal}"]
          atom.notifications.addError "Errors while instrumenting project files. Process was killed due to signal #{signal}.",
            detail: errors.join ""
          errors.push "Errors while instrumenting project files. Process was killed due to signal #{signal}."
          errorCallback.call @, errors


    onStopRunningProcess: ->
      if @runningProcess?
        @runningProcess.kill 'SIGKILL'
        @viewManager.views.logView.addEntry ["command", "kill -9 #{@runningProcess.pid}"]


    createTeSSLaEnv: (callback) ->
      # make sure callbacks are always defined
      callback = if callback? then callback else () -> {}
      # create container directory
      fs.mkdir @containerDir, =>
        # log make command
        @viewManager.views.logView.addEntry ["command", "mkdir #{@containerDir}"]
        # create build directory in container directory
        fs.mkdir path.join(@containerDir, "bin"), =>
          # log make command
          @viewManager.views.logView.addEntry ["command", "mkdir #{path.join @containerDir, "bin"}"]
          # now directories are prepared so just start docker
          callback()


    isTeSSLaEnvExisting: ({ ifYes, ifNot }) ->
      # make sure callbacks are always defined
      ifYes = if ifYes? then ifYes else () -> {}
      ifNot = if ifNot? then ifNot else () -> {}
      # if the mounted system is not existing anymore
      if fs.existsSync @containerDir
        ifYes()
      else
        ifNot()


    isDockerImageExisiting: ({ ifYes, ifNot }) ->
      # make sure callbacks are always defined
      ifYes = if ifYes? then ifYes else () -> {}
      ifNot = if ifNot? then ifNot else () -> {}
      # gather information about the docker needed docker image
      information = childProcess.execSync("docker images | grep #{TESSLA_IMAGE_NAME}")
      # console.log information
      if information.toString() isnt ""
        ifYes()
      else
        ifNot()


    isDockerContainerRunning: ({ ifYes, ifNot }) ->
      # make sure callbacks are always defined
      ifYes = if ifYes? then ifYes else () -> {}
      ifNot = if ifNot? then ifNot else () -> {}
      # get container ID. If the container is not running there will be no ID
      # returned by the process
      containerID = childProcess.execSync("docker ps -q -f name=#{TESSLA_CONTAINER_NAME}").toString()
      # if the container exists just call the callback. If not make the container
      # running
      if containerID isnt ""
        # call the if yes callback function
        ifYes()
      else
        # if the there was no ID the container is not running so call the ifNot
        # callback
        ifNot()


    isDockerDaemonRunning: ({ ifYes, ifNot }) ->
      # make sure callbacks are always defined
      ifYes = if ifYes? then ifYes else () -> {}
      ifNot = if ifNot? then ifNot else () -> {}

      # check if docker is running
      docker.info().then (resolved) =>
        ifYes()
      .catch (rejected) =>
        console.log "[TeSSLa2][debug]:controller.coffe:408: docker is not running", rejected
        ifNot()


    startDockerContainer: (callback) ->
      # make sure callbacks are always defined
      callback = if callback? then callback else () -> {}
      # define docker args
      dockerArgs = [
        "run",                                  # starting a container from an existing image
        "--volume", "#{@containerDir}:/tessla", # mounting the container in the given argument
        "-w", "/tessla",                        # setting the working directory (`cd /tessla` inside the container)
        "-tid",                                 # allocate a pseudo-TTY keep STDIN open even if not attached and tun container in background (-t -i -d -> `docker run -- help`)
        "--name", TESSLA_CONTAINER_NAME,        # name of the container will be the argument
        TESSLA_IMAGE_NAME,                      # specifies the name of the image
        "sh"                                    # executes the shell inside the container to prevent stopping the container imediatly
      ]
      # start process using defined arguments
      dockerContainer = childProcess.spawn "docker", dockerArgs
      # log command
      @messageQueue.enqueueEntry { type: "entry", title: "", label: "Docker", msg: "docker #{dockerArgs.join " "}" }
      @messageQueue.flush()
      # wait for docker comand
      dockerContainer.on "close", (code) =>
        if code? and code is 0
          # call callback function
          callback()


    dockerPull: (callback) ->
      # make sure callbacks are always defined
      callback = if callback? then callback else () -> {}
      # set flag that there was at least one initial pull
      @initiallyPulled = yes
      # update or download TeSSLa2
      @messageQueue.enqueueEntry { type: "entry", title: "", label: "Docker", msg: "docker pull #{TESSLA_REGISTRY}" }
      Downloader.dockerDownload
        callback: (output) =>
          # log all messages from the docker pull request
          for id, messages of output
            if id is "latest" or id is "unidentified"
              @messageQueue.enqueueEntries messages
            else if messages.length > 1
              @messageQueue.enqueueEntry { type: "listEntry", label: "Docker", title: id, msg: messages }
            else
              @messageQueue.enqueueEntry { type: "entry", label: "Docker", title: "", msg: messages[0] }
          # after processing all messages just flush them
          @messageQueue.flush()
          # execute callback
          callback()


    dockerPullRequest: () ->
      @isDockerDaemonRunning
        ifYes: => @dockerPull => @startDockerContainer()
        ifNot: =>
          # show notification to user
          message = "The Docker daemon does not respond. In most cases you just need to start Docker. If you started Docker and this message still appears check your Docker installation. If you forgot to start Docker just restart it and then execute a command in order to reactivate all package features."
          atom.notifications.addError "Docker daemon does not respond.",
            detail: message
          @messageQueue.enqueueEntries { type: "entry", title: "", label: "message", msg: message }
          @messageQueue.flush()


    transferFilesToContainer: ->
      fs.emptyDirSync @containerDir
      @viewManager.views.logView.addEntry ["command", "rm -rf #{@containerDir}/*"]

      fs.mkdirSync path.join @containerDir, "bin"
      @viewManager.views.logView.addEntry ["command", "mkdir #{@containerBuild}"]

      @viewManager.views.logView.addEntry ["command", "rsync -r --exclude=.gcc-flags.json #{@viewManager.activeProject.projPath}/* #{@containerDir}/"]

      fs.copySync @viewManager.activeProject.projPath, @containerDir
