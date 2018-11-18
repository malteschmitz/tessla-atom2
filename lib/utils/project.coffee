{ CompositeDisposable, Disposable, TextEditor } = require "atom"
{isChildOf, isSet} = require "../utils/utils"

fs = require("fs")
path = require("path")
fileSystem = require("fs")
childProcess = require("child_process")
YAML = require("yaml")
EventEmitter = require("events")
scanFolder = require("scan-folder")

module.exports=
  class Project extends EventEmitter
    constructor: ->
      @path = null
      @targets = null
      @subscriptions = new CompositeDisposable

      getProjectPath = (projPath) =>
        projectPaths = atom.project.getPaths()
        for project in projectPaths
          if isChildOf(projPath, project)
            return project;
        return null;

      activeEditor = atom.workspace.getActiveTextEditor()
      if isSet(activeEditor)
        @setPath(getProjectPath(activeEditor.getPath()))

      @subscriptions.add(
        atom.workspace.onDidChangeActivePaneItem((item) =>
          if item instanceof TextEditor
            @setPath(getProjectPath(item.getPath()))
          # else
          #   console.log(item)
          #   @setPath(null)
        )
      )

    checkGCCLinterConfig: =>
      return new Promise((resolve, reject) =>
        if fs.existsSync(path.join(@path, ".gcc-flags.json"))
          resolve()
        else
          clangPath = ""

          which = childProcess.spawn("which", ["clang"], { cwd: @path, shell: yes })
          which.stdout.on("data", (line) -> clangPath = line.toString().replace(/\r?\n|\r/g, ""))
          which.on("close", =>
            if clangPath.length > 0
              fileContent  = "{\n"
              fileContent += "\t\"execPath\": \"#{clangPath}\",\n"
              fileContent += "\t\"gccDefaultCFlags\": \"-Wall -c -fsyntax-only\",\n"
              fileContent += "\t\"gccIncludePaths\": \".,./include,./path\",\n"
              fileContent += "\t\"gccSuppressWarnings\": false\n"
              fileContent += "}"
              fs.writeFileSync(path.join(@path, ".gcc-flags.json"), fileContent, { flag: "wx"})
              resolve()
          )
      )

    checkTargetsYAML: =>
      return new Promise((resolve, reject) =>
        if fs.existsSync(path.join(@path, "targets.yml"))
          resolve()
        else
          allow = { dotfolders: yes, dotfiles: yes, modules: yes }
          cFiles = scanFolder(@path, ".c", yes, allow)
          tesslaFiles = scanFolder(@path, ".tessla", yes, allow)
          inputFiles = scanFolder(@path, ".input", yes, allow)

          if isSet(tesslaFiles) and tesslaFiles.length is 0
            tesslaFiles.push(path.join(@path, "spec.tessla"))

          if isSet(inputFiles) and inputFiles.length is 0
            inputFiles.push(path.join(@path, "trace.input"))

          if isSet(cFiles) and cFiles.length is 0
            cFiles.push(path.join(@path, "file_1.c"))
            cFiles.push(path.join(@path, "file_2.c"))
          cFiles = cFiles.map((file) => path.relative(@path, file))

          fs.writeFileSync(
            path.join(@path, "targets.yml"),
            "# The \"targets\" key specifies the different file constellations. You can specify as much\n" +
            "# such constallations as you wish. To switch the considered configuration just change\n" +
            "# the \"active\" key to match the target you wish.\n" +
            "#\n" +
            "# A target can contain the following properties\n" +
            "# \t- binName: The name for the executable C binary and the created trace file\n" +
            "# \t- tessla: A single tessla specification file that will be considered by tessla and tessla_rv\n" +
            "# \t- input: A single tracefile\n" +
            "# \t- c: A list of C files that should be compiled\n\n",
            { flag: "wx" }
          )
          fileContent = {
            "active": "main",
            "targets": {
              "main": {
                binName: path.basename(@path)
                tessla: path.relative(@path, tesslaFiles[0]),
                input: path.relative(@path, inputFiles[0])
              },
              "debug": {
                binName: path.basename(@path)
                tessla: path.relative(@path, tesslaFiles[0]),
                c: cFiles
              }
            }
          }
          fs.writeFileSync(path.join(@path, "targets.yml"), YAML.stringify(fileContent), { flag: "a" })
          resolve()
      )

    parseTargets: =>
      return new Promise((resolve, reject) =>
        file = fs.readFileSync(path.join(@path, "targets.yml"), "utf8")
        @targets = YAML.parse(file)
        if not isSet(@targets.targets)
          @targets.targets = {}
        for k, v of @targets.targets
          if not isSet(v.binName)
            @targets.targets[k].binName = path.basename(@path).replace(/\s/g, "_")
        resolve()
      )

    setPath: (projPath) =>
      if not isSet(projPath)
        @path = null
      else if projPath isnt @path
        @path = projPath
        @checkGCCLinterConfig()
        .then(@checkTargetsYAML)
        .then(@parseTargets)
        .then(=>
          fs.watchFile(path.join(@path, "targets.yml"), (curr, prev) =>
            @emit("targets-changed")
          )
          @emit("project-dir-changed")
        ).catch((err) =>
          console.log("error while project structure setup")
          console.log(err)
        )

    readTarget: =>
      return new Promise((resolve, reject) =>
        @checkTargetsYAML().then(=>
          file = fs.readFileSync(path.join(@path, "targets.yml"), "utf8")
          @targets = YAML.parse(file)
          for k, v of @targets.targets
            if not isSet(v.binName)
              @targets.targets[k].binName = path.basename(@path).replace(/\s/g, "_")
          if @targets.active is null && @targets.targets isnt null
            return activeTarget = @targets.targets[Object.keys(@targets.targets)[0]]
          if @targets.targets is null or @targets.targets.length is 0
            return null
          activeTarget = null
          for k, v of @targets.targets
            if @targets.active is k
              activeTarget = v
          if activeTarget is null
            activeTarget = @targets.targets[Object.keys(@targets.targets)[0]]
          resolve(activeTarget)
        ).catch((err) =>
          reject(err)
        )
      )


    getPath: =>
      return @path

    getTargets: =>
      return @targets

    dispose: =>
      @subscriptions.dispose()
