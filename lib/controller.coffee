path = require "path"
childProcess = require "child_process"
fs = require "fs-extra"
os = require "os"

MessageView = require "./message-view"
FileManager = require "./file-manager"
{ MESSAGE_TYPE } = require "./constants";

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

      # define format for events
      formats  = "[formats]\n"
      formats += "variable_values = \"#{atom.config.get "tessla2.variableValueFormatting"}\"\n"
      formats += "function_calls = \"#{atom.config.get "tessla2.functionCallFormatting"}\"\n"
      # define rules where to put information gathered
      rules  = "[rules]\n";
      rules += "variable_values_cat.DEBUG \"instrumented_#{binaryName}.trace\"; variable_values\n";
      rules += "function_calls_cat.DEBUG \"instrumented_#{binaryName}.trace\"; function_calls\n";

      fs.unlink zlogFile if fs.existsSync zlogFile
      fs.writeFileSync zlogFile, formats + rules



    onCompileAndRunCCode: ->
      unless @viewManager.activeProject.projPath?
        @viewManager.showNoProjectNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      console.log "compile and run c code"

      @viewManager.saveEditors()
      @onBuildCCode
        buildAssembly: no
        onSuccess: -> @onRunBinary



    onCompileAndRunProject: ->
      if @viewManager.activeProject.projPath is ""
        @viewManager.showNoProjectNotification()
        return

      if @runningProcess?
        @viewManager.showCurrentlyRunningProcessNotification()
        return

      @viewManager.saveEditors()
      @onBuildCCode
        buildAssembly: yes
        onSuccess: -> @onPatchAssembly
          onSuccess: -> @onBuildAssembly
            onSuccess: -> @onRunPatchedBinary
              onSuccess: -> @onBuildTeSSLa
                onError: -> @viewManager.highlightTeSSLaError
                onSuccess: -> @onRunTeSSLa
                  onSuccess: (lines) ->
                    @viewManager.views.formattedOutputView.update lines



    onPatchAssembly: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      binaryName = @viewManager.activeProject.binName

      # set up command
      args = [
        "exec", "tessla", "/usr/lib/llvm-3.8/bin/opt", "-load", "/InstrumentFunctions/libInstrumentFunctions.so",
        "-instrument_function_calls", path.join "build", "#{binaryName}.bc"
      ]

      FileManager.collectCFunctionsFromSourceFile
        sourceFile: @viewManager.activeProject.tesslaFiles[0]
        projectPath: @viewManager.activeProject.projPath
      .forEach (func) ->
        args = args.concat ["-instrument", func.functionName]

      args = args.concat ["-o", "build/instrumented_#{binaryName}.bc"]

      @checkDockerContainer()
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, command

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsCView.addEntry data.toString()
        errors.push data.toString()

      @runningProcess.on "close", () =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        if errors.length is 0
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "Successfully patched Assembly"
          atom.notifications.addSuccess "Successfully patched Assembly"
          successCallback.call @

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while patching Assembly"
          atom.notifications.addError "Errors while patching Assembly",
            detail: errors.join ""
          errorCallback.call @



    onBuildTeSSLa: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      unless @viewManager.activeProject.tesslaFiles?
        @viewManager.showNoCompilableTeSSLaFilesNotification()
        return

      @viewManager.showTooMuchCompilableTeSSLaFilesNotification() if @viewManager.activeProject.tesslaFiles.length > 1

      fileActiveProject = @viewManager.activeProject.tesslaFiles[0]

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      args = [
        "exec", "tessla", "java", "-jar", "/tessla-imdea-snapshot.jar",
        path.relative @viewManager.activeProject.projPath, fileActiveProject .replace /\\/g, "/",
      ]

      @checkDockerContainer()
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, command

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        outputs.push data.toString()

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        errors.push data.toString()

      @runningProcess.on "close", () =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        stdout = outputs.join()
        stderr = errors.join()

        if stdout.charAt 0 is "{"
          stdout = "#{stdout.slice 0, -2}\n" if stdout.charAt(stdout.length - 2) is ","

          fs.writeFileSync path.join(@containerBuild, "instrumented_#{@viewManager.activeProject.binName}.tessla.json"), stdout

          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "Successfully compiled #{path.relative(@viewManager.activeProject.projPath, fileActiveProject).replace(/\\/g, "/")}"
          @viewManager.removeTeSSLaSourceMarkers()

          atom.notifications.addSuccess "Successfully compiled TeSSLa file"

          successCallback.call @

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while compiling #{fileActiveProject}"
          @viewManager.views.errorsTeSSLaViews.addEntry stderr + stdout

          atom.notifications.addError "Errors while compiling TeSSLa file",
            detail: stderr + stdout

          errorCallback.call @,
            error: stderr + stdout
            file: fileActiveProject



    onBuildAssembly: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      args = [
        "exec", "tessla", "clang++", path.join("build", "instrumented_#{@viewManager.activeProject.binName}.bc"),
        "-o", "build/instrumented_#{@viewManager.activeProject.binName}", "-lzlog", "-lpthread",
        "-L/usr/local/lib", "-L/InstrumentFunctions", "-lLogger",
      ]

      @checkDockerContainer()
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, command

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsCView.addEntry data.toString()
        errors.push data.toString()

      @runningProcess.on "close", () =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        if errors.length is 0
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "Successfully compiled Assembly"
          atom.notifications.addSuccess "Successfully compiled Assembly"
          successCallback.call @

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while compiling Assembly"
          atom.notifications.addError "Errors while compiling Assembly",
            detail: errors.join ""
          errorCallback.call @



    onBuildCCode: ({ buildAssembly, onSuccess, onError }) ->
      assemblyFlag = buildAssembly ? no
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      console.log "on build c code"

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

      outFile = path.join "build", (@viewManager.activeProject.binName + if assemblyFlag then ".bc" else "")
      args = ["exec", "tessla", "clang", "-o", outFile]
      args = args.concat ['-emit-llvm', '-S'] if assemblyFlag

      args = args.concat @viewManager.activeProject.cFiles.map (arg) =>
        path.relative @viewManager.activeProject.projPath, arg .replace /\\/g, "/"

      @checkDockerContainer()
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, command

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsCView.addEntry data.toString()
        errors.push data.toString()

      @runningProcess.on "close", () =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        if errors.length is 0
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "Successfully compiled C files"
          atom.notifications.addSuccess "Successfully compiled C files"
          successCallback.call @

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while compiling C files"
          atom.notifications.addError "Errors while compiling C files",
            detail: errors.join ""
          errorCallback.call @



    onRunPatchedBinary: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      traceFile = path.join @containerDir, "instrumented_#{@viewManager.activeProject.binName}.trace"
      if fs.existsSync traceFile
        fs.renameSync traceFile, "#{traceFile}.#{+new Date}"

      args = ["exec", "tessla", "./build/instrumented_#{@viewManager.activeProject.binName}"]

      @checkDockerContainer()
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, command

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        @viewManager.views.consoleView.addEntry data.toString()
        outputs.push data.toString()

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsCView.addEntry data.toString()
        errors.push data.toString()

      @runningProcess.on 'close', (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry "Process exited with code #{code}" if code?
        @viewManager.views.consoleView.addEntry "Process was killed due to signal #{signal}" if signal?

        if errors.length is 0
          successCallback.call @

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while running the patched binary"
          atom.notifications.addError('Errors while running the patched binary', { detail: errors.join('') });
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
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args

      binary = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, binary

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        @viewManager.views.consoleView.addEntry data.toString()
        outputs.push data.toString()

      errors = []
      @runningProcess.stderr.on 'data', (data) =>
        @viewManager.views.errorsCView.addEntry data.toString()
        errors.push data.toString()

      @runningProcess.on 'close', (code, signal) =>
        @runningProcess = null

        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry "Process exited with code #{code}" if code?
        @viewManager.views.consoleView.addEntry "Process was killed due to signal #{signal}" if signal?

        if errors.length is 0
          successCallback.call @

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while running C binary"
          atom.notifications.addError "Errors while running the C binary",
            detail: errors.join ""
          errorCallback.call @



    onRunTeSSLa: ({ onSuccess, onError }) ->
      successCallback = onSuccess ? ->
      errorCallback = onError ? ->

      unless @viewManager.activeProject.projPath?
        @viewManager.showNoProjectNotification()
        return

      tsslJSON = path.join @containerBuild, "instrumented_#{@viewManager.activeProject.binName}.tessla.json"
      unless fs.existsSync tsslJSON
        @viewManager.showNoTeSSLaJSONFoundNotification()
        return

      JSONString = fs.readFileSync(tsslJSON).toString()
      tsslJSONContent = JSON.parse(JSONString).items

      outputArgs = [
        "LANG=C.UTF-8", "/tessla_server", path.relative @containerDir, tsslJSON .replace /\\/g, "/"
        "--trace", "instrumented_#{@viewManager.activeProject.binName}.trace"
      ]

      for key, stream of tsslJSONContent
        if stream.out? and stream.name?
          outputArgs.push "-o"
          outputArgs.push "#{stream.id}:#{stream.name}"

      @viewManager.disableButtons()
      @viewManager.enableStopButton()

      args = ["exec", "tessla", "sh", "-c", "'#{outputArgs.join " "}'"];

      @checkDockerContainer()
      console.log "spawn docker #{args.join " "}"
      @runningProcess = childProcess.spawn "docker", args,
        shell: yes

      command = "docker #{args.join " "}"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, command

      outputs = []
      @runningProcess.stdout.on "data", (data) =>
        @viewManager.views.consoleView.addEntry data.toString()
        outputs.push data.toString()

      errors = []
      @runningProcess.stderr.on "data", (data) =>
        @viewManager.views.errorsTeSSLaViews.addEntry data.toString()
        errors.push data.toString()

      @runningProcess.on 'close', (code, signal) =>
        @runningProcess = null
        @viewManager.enableButtons()
        @viewManager.disableStopButton()

        @viewManager.views.consoleView.addEntry "Process exited with code #{code}" if code?
        @viewManager.views.consoleView.addEntry "Process was killed due to signal #{signal}" if signal?

        if errors.length is 0
          successCallback.call @, outputs

        else
          @viewManager.views.logView.addEntry MESSAGE_TYPE.MSG, "An error occurred while running the TeSSLa server"
          atom.notifications.addError "Errors while running TeSSLa server",
            detail: errors.join ""
          errorCallback.call @



    onStopRunningProcess: ->
      if @runningProcess?
        @runningProcess.kill 'SIGKILL'
        @viewManager.views.logView.addEntry MESSAGE_TYPE.CMD, "kill -9 #{@runningProcess.pid}"



    checkDockerContainer: ->
      if childProcess.execSync("docker ps -q -f name=tessla").toString() is ""
        args = [
          "run", "--volume", "#{@containerDir}:/tessla", "-w", "/tessla", "-tid",
          "--name", "tessla", "tessla", "sh"
        ]

        childProcess.spawnSync 'docker', args
        @viewManager.views.logView.addEntry MESSAGE_TYPE.DKR, "docker #{args.join " "}"



    transferFilesToContainer: ->
      fs.emptyDirSync @containerDir
      @viewManager.views.logView.addEntry MESSAGE_TYPE.CMD, "rm -rf ${this.containerDir}/*"

      fs.mkdirSync path.join @containerDir, "build"
      @viewManager.views.logView.addEntry MESSAGE_TYPE.CMD, "mkdir ${this.containerBuild}"

      @createZLogFile()
      @viewManager.views.logView.addEntry MESSAGE_TYPE.CMD, "rsync -r --exclude=build,.gcc-flags.json #{@viewManager.activeProject.projPath}/* #{@containerDir}/"

      fs.copy @viewManager.activeProject.projPath, @containerDir,
        filter: (src) ->
          yes if path.posix.basename(src) is '.gcc-flags.json'
          no if path.posix.basename(src) is 'build'
          yes
