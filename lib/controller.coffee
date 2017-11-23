path = require "path"
childProcess = require "child_process"
fs = require "fs-extra"
os = require "os"

FileManager = require "./file-manager"
{TESSLA_IMAGE_NAME, TESSLA_CONTAINER_NAME} = require "./constants"

module.exports=
  class Controller
    sfConfig:
      dotfolder: no
      dotfiles: no
      modules: no

    constructor: (@viewManager) ->
      @runningProcess = null
      @containerDir = path.join os.homedir(), ".tessla-env"
      @containerBuild = path.join @containerDir, "build"


    createZLogFile: ->
      binaryName = @viewManager.activeProject.binName
      zlogFile = path.join @containerDir, "zlog.conf"

      formats  = "[formats]\n"
      formats += "variable_values = \"#{atom.config.get "tessla2.variableValueFormatting"}\"\n"
      formats += "function_calls = \"#{atom.config.get "tessla2.functionCallFormatting"}\"\n"
      rules    = "[rules]\n";
      rules   += "variable_values_cat.DEBUG \"instrumented_#{binaryName}.trace\"; variable_values\n";
      rules   += "function_calls_cat.DEBUG \"instrumented_#{binaryName}.trace\"; function_calls\n";

      fs.unlink zlogFile if fs.existsSync zlogFile
      fs.writeFileSync zlogFile, formats + rules


    onCompileAndRunCCode: ->
      unless @viewManager.activeProject.projPath?
        @viewManager.showNoProjectNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.saveEditors()
      @onBuildCCode
        onSuccess: -> @onRunBinary {}


    onCompileAndRunProject: ->
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.saveEditors()
      @onDoRV
        onSuccess: (lines) ->
          @viewManager.views.logView.addEntry ["message", "Verification successfully finished."]
          @viewManager.views.formattedOutputView.update lines
        onError: (errs) -> console.log errs


    onBuildCCode: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

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

      outFile = path.join "build", @viewManager.activeProject.binName

      args = ["exec", TESSLA_CONTAINER_NAME, "clang", "-o", outFile]
      args = args.concat @viewManager.activeProject.cFiles.map (arg) =>
        path.relative @viewManager.activeProject.projPath, arg .replace /\\/g, "/"

      @checkDockerContainer()
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", command]

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


    onRunBinary: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      unless @viewManager.activeProject.projPath?
        @viewManager.showNoProjectNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      args = ["exec",  TESSLA_CONTAINER_NAME, "./build/#{@viewManager.activeProject.binName}"]

      @checkDockerContainer()
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

        if errors.length is 0
          successCallback.call @

        else
          @viewManager.views.logView.addEntry ["message", "An error occurred while running C binary"]
          atom.notifications.addError "Errors while running the C binary",
            detail: errors.join ""
          errorCallback.call @

    filterScriptOutput: (line, stdout, errors, outputs) ->
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
          @viewManager.views.errorsTeSSLaView.addEntry [suffix]
          errors.push suffix
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

    onDoRV: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        return

      unless @viewManager.activeProject.cFiles?
        @viewManager.showNoCompilableCFilesNotification()
        return

      unless @viewManager.activeProject.tesslaFiles?
        @viewManager.showNoCompilableTeSSLaFilesNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      @transferFilesToContainer()

      cFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.cFiles[0]
      tsslFile = path.relative @viewManager.activeProject.projPath, @viewManager.activeProject.tesslaFiles[0]

      args = ["exec", TESSLA_CONTAINER_NAME, "tessla_rv", "#{cFile}", "#{tsslFile}"]

      @checkDockerContainer()
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
        console.log "stdout:", lines
        for line in lines
          @filterScriptOutput line, true, errors, outputs

      @runningProcess.stderr.on "data", (data) =>
        # line = data.toString()
        # console.log line
        # @filterScriptOutput line, errors, outputs
        lines = data.toString().split "\n"
        lines = lines.filter (v) => v isnt ""
        console.log "stderr:", lines
        for line in lines
          @filterScriptOutput line, false, errors, outputs

      @runningProcess.on "close", (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry ["<strong>Process exited with code #{code}.</strong>"]  if code?
        @viewManager.views.consoleView.addEntry ["<strong>Process was killed due to signal #{signal}.</strong>"]  if signal?

        console.log errors

        if errors.length is 0
          # @viewManager.views.logView.addEntry ["message", "Successfully compiled C sources"]
          # atom.notifications.addSuccess "Successfully compiled C sources"
          successCallback.call @, outputs

        else
          @viewManager.views.logView.addEntry ["message", "An error occurred while compiling project files"]
          atom.notifications.addError "Errors while compiling project files",
            detail: errors.join ""
          errorCallback.call @


    onStopRunningProcess: ->
      if @runningProcess?
        @runningProcess.kill 'SIGKILL'
        @viewManager.views.logView.addEntry ["command", "kill -9 #{@runningProcess.pid}"]


    checkDockerContainer: ->
      if childProcess.execSync("docker ps -q -f name=#{TESSLA_CONTAINER_NAME}").toString() is ""

        args = [
          "run", "--volume", "#{@containerDir}:/tessla", "-w", "/tessla", "-tid",
          "--name", TESSLA_CONTAINER_NAME, TESSLA_IMAGE_NAME, "sh"
        ]

        # make sure the actual container ist not still alive and remove it forcefully
        childProcess.spawnSync "docker", ["rm", "-f", TESSLA_CONTAINER_NAME]

        # after that you can start a new one
        childProcess.spawnSync "docker", args
        @viewManager.views.logView.addEntry ["Docker", "docker #{args.join " "}"]


    transferFilesToContainer: ->
      fs.emptyDirSync @containerDir
      @viewManager.views.logView.addEntry ["command", "rm -rf #{@containerDir}/*"]

      fs.mkdirSync path.join @containerDir, "build"
      @viewManager.views.logView.addEntry ["command", "mkdir #{@containerBuild}"]

      @createZLogFile()
      @viewManager.views.logView.addEntry ["command", "rsync -r --exclude=build,.gcc-flags.json #{@viewManager.activeProject.projPath}/* #{@containerDir}/"]

      fs.copy @viewManager.activeProject.projPath, @containerDir,
        filter: (src) ->
          no if path.posix.basename(src) is 'build'
          yes
