path = require "path"
fileSystem = require "fs"
childProcess = require "child_process"
scanFolder = require "scan-folder"

module.exports=
  class Project
    sfConfig:
      dotfolder: no
      dotfiles: no
      modules: no


    constructor: (@projPath) ->
      @outputDir = ""
      @binName = ""

      if @projPath?
        @updateOutputDir()
        @updateBinName()

      else
        @projPath = ""

      cFiles = @getCFiles()
      tesslaFiles = @getTeSSLaFiles()


    setProjPath: (projPath) ->
      @projPath = projPath
      @updateOutputDir()
      @updateBinName()

      @cFiles = @getCFiles()
      @tesslaFiles = @getTeSSLaFiles()


    updateOutputDir: ->
      @outputDir = path.join @projPath, "build"


    updateBinName: ->
      @binName = path.basename(@projPath).replace " ", "_"


    getCFiles: ->
      files = scanFolder @projPath, ".c", yes, @sfConfig
      files = null if files.length is 0
      files


    getTeSSLaFiles: ->
      files = scanFolder @projPath, ".tessla", yes, @sfConfig
      files = null if files.length is 0
      files


    setUpProjectStructure: ->
      unless fileSystem.existsSync path.join @projPath, ".gcc-flags.json"
        which = childProcess.spawn "which", ["clang"],
          cwd: @projPath
          shell: yes

        clangPath = ""
        which.stdout.on "data", (line) -> clangPath = line.toString()
        clangPath = clangPath.replace /\r?\n|\r/g, ""

        which.on "close", =>
          if clangPath.length > 0
            fileContent  = "{\n"
            fileContent += "\t\"execPath\": \"#{clangPath}\",\n"
            fileContent += "\t\"gccDefaultCFlags\": \"-Wall -c -fsyntax-only\",\n"
            fileContent += "\t\"gccIncludePaths\": \".,./include,./path\",\n"
            fileContent += "\t\"gccSuppressWarnings\": false\n"
            fileContent += "}"

            fileSystem.writeFileSync path.join @projPath, ".gcc-flags.json", fileContent


    clear: ->
      @projPath = ""
      @outputDir = ""
      @binName = ""
