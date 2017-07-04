path = require "path"
childProcess = require "child_process"
fs = require "fs-extra"
os = require "os"

FileManager = require "./file-manager"

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
        onSuccess: (lines) -> @viewManager.views.formattedOutputView.update lines
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

      args = ["exec", "tessla", "clang", "-o", outFile]
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

      args = ["exec", "tessla", "./build/#{@viewManager.activeProject.binName}"]

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

        @viewManager.views.consoleView.addEntry ["Process exited with code #{code}."]  if code?
        @viewManager.views.consoleView.addEntry ["Process was killed due to signal #{signal}."]  if signal?

        if errors.length is 0
          successCallback.call @

        else
          @viewManager.views.logView.addEntry ["message", "An error occurred while running C binary"]
          atom.notifications.addError "Errors while running the C binary",
            detail: errors.join ""
          errorCallback.call @


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

      args = ["exec", "tessla", "tessla_rv", "#{cFile}", "#{tsslFile}"]

      @checkDockerContainer()
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry ["Docker", command]

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        line = data.toString()
        if line.substr(0, 11) is "[TeSSLa RV]"
          @viewManager.views.logView.addEntry ["TeSSLa RV", line.substr(11).trim()]
        else
          outputs.push line
          @viewManager.views.consoleView.addEntry [line]


      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsTeSSLaView.addEntry [data.toString()]
        errors.push data.toString()

      @runningProcess.on "close", (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry ["Process exited with code #{code}."]  if code?
        @viewManager.views.consoleView.addEntry ["Process was killed due to signal #{signal}."]  if signal?

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
      if childProcess.execSync("docker ps -q -f name=tessla").toString() is ""
        args = [
          "run", "--volume", "#{@containerDir}:/tessla", "-w", "/tessla", "-tid",
          "--name", "tessla", "tessla", "sh"
        ]

        childProcess.spawnSync 'docker', args
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
