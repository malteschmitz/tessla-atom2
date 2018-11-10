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
            "# The \"active\" key specifies the the files which should be considered during compiliation.\n" +
            "# The files are split grouped by type where \"tessla\" contains a single spec file written\n" +
            "# in TeSSLa. The \"input\" key contains a single trace file which substitutes a whole c\n" +
            "# programm. The key \"c\" contains a list of c files which should be verified by the TeSSLa\n" +
            "# spec.\n" +
            "#\n" +
            "# The \"targets\" key specifies the different file constellations. You can specify as much\n" +
            "# such constallations as you wish. To switch the considered configuration just change\n" +
            "# the \"active\" key to match the target you wish.\n\n",
            { flag: "wx" }
          )
          fileContent = {
            "active": "main",
            "targets": {
              "main": {
                tessla: path.relative(@path, tesslaFiles[0]),
                input: path.relative(@path, inputFiles[0])
              },
              "debug": {
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
          @emit("project-dir-changed")
        )
        .catch((err) =>
          console.log("error while project structure setup")
          console.log(err)
        )

    getTarget: =>
      file = fs.readFileSync(path.join(@path, "targets.yml"), "utf8")
      @targets = YAML.parse(file)
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
      return activeTarget

    getPath: =>
      return @path

    getTargets: =>
      return @targets

    dispose: =>
      @subscriptions.dispose()
