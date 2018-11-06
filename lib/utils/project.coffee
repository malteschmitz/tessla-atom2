{ CompositeDisposable, Disposable, TextEditor } = require "atom"
{isChildOf, isSet} = require "../utils/utils"

fs = require("fs")
path = require("path")
fileSystem = require("fs")
childProcess = require("child_process")
YAML = require("yaml")

module.exports=
  class Project
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
        if fs.existsSync(path.join(@path, ".targets.yml"))
          resolve()
        else
          fileContent = {
            "target.main": {
              active: yes,
              tessla: "spec.tessla",
              input: "trace.input",
            }
          }
          fs.writeFileSync(path.join(@path, ".targets.yml"), YAML.stringify(fileContent), { flag: "wx" })
          resolve()
      )

    parseTargets: =>
      return new Promise((resolve, reject) =>
        file = fs.readFileSync(path.join(@path, ".targets.yml"), "utf8")
        @targets = YAML.parse(file)
        resolve()
      )

    setPath: (projPath) =>
      if not isSet(projPath)
        @path = null
      else if projPath isnt @path
        console.log("changed project to path:", projPath)
        @path = projPath
        @checkGCCLinterConfig()
        .then(@checkTargetsYAML)
        .then(@parseTargets)
        .catch((err) =>
          console.log("error while project structure setup")
          console.log(err)
        )

    getTarget: =>
      activeTarget = null
      for k, v of @targets
        if v.active is yes
          activeTarget = v
      if activeTarget is null && @targets isnt null
        activeTarget = @targets[Object.keys(@targets)[0]]
      return activeTarget

    getPath: =>
      return @path

    getTargets: =>
      return @targets

    dispose: =>
      @subscriptions.dispose()
