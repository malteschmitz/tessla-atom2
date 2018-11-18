fs = require("fs-extra")
os = require("os")
path = require("path")
childProcess = require("child_process")

{TESSLA_CONTAINER_NAME} = require("../utils/constants")
{isSet} = require("../utils/utils")
Logger = require("../utils/logger")

module.exports=
  class TeSSLaLinter
    constructor: ->
      @name = "Example"
      @scope = "file"
      @lintsOnChange = no
      @grammarScopes = ["tessla"]
      @lint = @onLint

    onLint: (textEditor) =>
      return new Promise (resolve, reject) =>
        if not isSet(textEditor) or not isSet(textEditor.getPath())
          return

        args = ["exec", TESSLA_CONTAINER_NAME, "tessla", "#{textEditor.getTitle()}", "--verify-only"]
        command = "docker #{args.join " "}"
        Logger.log("Linter.onLint()", command)

        editorPath = textEditor.getPath()
        verifier = childProcess.spawn("docker", args)

        errors = []
        warnings = []

        verifier.stdout.on "data", (data) ->
          Logger.log("Linter.onLint()", "verifier stdout: " + data.toString())
        verifier.stderr.on "data", (data) ->
          Logger.log("Linter.onLint()", "verifier stderr: " + data.toString())
          for line in data.toString().split("\n")
            lineIsError = line.substr(0, 5) is "Error"
            lineIsWarning = line.substr(0, 7) is "Warning"
            errors.push(line) if line isnt "" and lineIsError
            warnings.push(line) if line isnt "" and lineIsWarning
        verifier.on "close", () ->
          # get an array of items
          items = []
          # regex
          regex = /(Error|Warning)\s*:\s*(\w[\w\.]*)\s*\(([\d]+)+\s*,\s*([\d]+)\s*-\s*([\d]+)\s*,\s*([\d]+)\)\s*:([\w\s]*)/gm
          # parse error messages
          for error in errors
            while matches = regex.exec(error)
              items.push(
                  severity: "error"
                  location:
                    file: editorPath
                    position: [[matches[3] - 1, matches[4] - 1], [matches[5] - 1, matches[6] - 1]]
                  excerpt: matches[7]
                  description: ""
              )
          # parse warning messages
          for warning in warnings
            while matches = regex.exec(warning)
              items.push(
                  severity: "warning"
                  location:
                    file: editorPath
                    position: [[matches[3] - 1, matches[4] - 1], [matches[5] - 1, matches[6] - 1]]
                  excerpt: matches[7]
                  description: ""
              )
          # Do something sync
          resolve(items)
