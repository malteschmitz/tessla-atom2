
path = require "path"
fs = require "fs"
showdown = require "showdown"
childProcess = require("child_process")
converter = new showdown.Converter()
Logger = require("../utils/logger")
{isSet} = require("../utils/utils")
{TESSLA_CONTAINER_NAME} = require("../utils/constants")

module.exports=
  class TeSSLaAutocompleter
    constructor: ->
      @selector = "tessla"
      @disableForSelector = "string, comment"
      @inclusionPriority = 100
      @excludeLowerPriority = yes
      @suggestionPriority = 2
      @filterSuggestions = yes

      @running = no
      @forceResolve = null
      @lastTriggered = null


    getSuggestions: (options) =>
      # to make decrease cpu usage stop other
      if @running or isSet(@lastTriggered) and Date.now() - @lastTriggered < 200
        @running = no
        @forceResolve()
        return null
      else
        return new Promise((resolve, reject) =>
          Logger.log("TeSSLaAutocompleter.getSuggestions()")
          @lastTriggered = Date.now()
          @running = yes
          @forceResolve = resolve
          editor = options.editor
          prefix = options.prefix
          @findMatchingSuggestions(prefix, editor)
            .then((suggestions) =>
              @running = no
              resolve(suggestions)
            )
        )


    resolveIncludes: (editor) =>
      Logger.log("TeSSLaAutocompleter.resolveIncludes()")
      content = editor.getText()
      regex = /^include\s*"(.*)"$/gm
      files = []
      while (result = regex.exec(content)) isnt null
        #group 1: filePath
        files.push(result[1])
      return files


    getFileContentsFromDocker: (files) =>
      return new Promise((resolve, reject) =>
        args = ["exec", TESSLA_CONTAINER_NAME, "cat"]
        for file in files
          args.push(file)
        cat = childProcess.spawn("docker", args)
        fileContents = ""
        cat.stdout.on("data", (data) => fileContents += data.toString())
        error = ""
        hadError = no
        cat.stderr.on("data", (data) =>
          hadError = yes
          error += data.toString()
        )
        cat.on("close", (code, signal) =>
          if hadError
            reject(error)
          else
            resolve(fileContents)
        )
      )


    findMatchingSuggestions: (prefix, editor) =>
      return new Promise((resolve, reject) =>
        Logger.log("TeSSLaAutocompleter.findMatchingSuggestions()")
        files = @resolveIncludes(editor)
        suggestions = @findSymbolsFromFile(editor.getText(), prefix)
        @getFileContentsFromDocker(files).then((contents) =>
          suggestions = suggestions.concat(@findSymbolsFromFile(contents, prefix))
          suggestions = suggestions.concat(@findKeywords(prefix))
          suggestions.sort((a, b) =>
            if a.text < b.text
              return -1
            if a.text > b.text
              return 1
            return 0
          )
          resolve(suggestions)
        ).catch((err) =>
          Logger.err(err)
        )
      )


    createInSuggestion: (name, type, comment, annotation) =>
      return {
        text: name,
        type: "variable",
        leftLabel: "in: #{type}",
        rightLabel: annotation,
        description: comment
      }


    createDefFunctionSuggestion: (name, params, comment, annotation) =>
      paramNames = []
      paramTypes = []
      paramRegex = /(\w[\w\d_]*)\s*:\s*([\w\[\],=>\s\(\)]+)\s*(?:,|$)/gm
      while (result = paramRegex.exec(params)) isnt null
        #group 1: param name
        #group 2: param type
        paramNames.push(result[1])
        paramTypes.push(result[2])
      nameRegex = /(\w[\w\d_]*)\s*(?:\[|$)/gm
      snippet = ""
      for i in [0...paramNames.length]
        snippet += "${#{i+1}:#{paramNames[i]}: #{paramTypes[i]}}, "
      return {
        text: name,
        displayText: "#{name}(#{paramTypes.join(", ")})"
        snippet: "#{nameRegex.exec(name)[1]}(#{snippet.slice(0,-2)})",
        type: "function",
        rightLabel: annotation,
        description: comment
      }


    createDefVarSuggestion: (name, type, comment, annotation) =>
      return {
        text: name,
        type: "variable",
        leftLabel: type,
        rightLabel: annotation,
        description: comment
      }


    findKeywords: (name) =>
      suggestions = []
      if "true".startsWith(name.toLowerCase())
        suggestions.push({ text: "true", type: "constant" })
      if "false".startsWith(name.toLowerCase())
        suggestions.push({ text: "false", type: "constant" })
      if "if".startsWith(name)
        suggestions.push({ text: "if", snippet: "if ${1:cond} then ${2:expr} else ${3:expr}", type: "keyword" })
      if "else".startsWith(name)
        suggestions.push({ text: "else", type: "keyword" })
      if "then".startsWith(name)
        suggestions.push({ text: "then", type: "keyword" })
      if "where".startsWith(name)
        suggestions.push({ text: "where", type: "keyword" })
      if "in".startsWith(name)
        suggestions.push({ text: "in", snippet: "in ${1:var}", type: "keyword" })
      if "out".startsWith(name)
        suggestions.push({ text: "out", snippet: "out ${1:var}", type: "keyword" })
      if "include".startsWith(name)
        suggestions.push({ text: "include", snippet: "include ${1:file}", type: "keyword" })
      if "def".startsWith(name)
        suggestions.push({ text: "def", snippet: "def ${1:name}: ${2:type} := ${3:expr}", type: "keyword" })
        suggestions.push({ text: "def", snippet: "def ${1:name}(${2:params}) := ${3:expr}", type: "keyword" })
        suggestions.push({ text: "def", snippet: "def ${1:name} := ${2:expr}", type: "keyword" })
      if "Signal".startsWith(name)
        suggestions.push({ text: "Signal", type: "type" })
      if "Events".startsWith(name)
        suggestions.push({ text: "Events", type: "type" })
      if "Int".startsWith(name)
        suggestions.push({ text: "Int", type: "type" })
      if "Float".startsWith(name)
        suggestions.push({ text: "Float", type: "type" })
      if "String".startsWith(name)
        suggestions.push({ text: "String", type: "type" })
      if "Boolean".startsWith(name)
        suggestions.push({ text: "Boolean", type: "type" })
      if "Unit".startsWith(name)
        suggestions.push({ text: "Unit", type: "type" })
      return suggestions


    findSymbolsFromFile: (source, name) =>
      Logger.log("TeSSLaAutocompleter.findSymbolsFromFile()")
      suggestions = []
      regex = ///
        ((?:#.*\s+)+)?  # extract comments
        (@.+\s+)?       # extract annotations
        (?:
          (?:\s*^in\s+(\w[\w\d_]*)\s*(?::\s*([\w\[\]\d]*)))|                               # in streams
          #(?:\s*^out\s*(\w[\w\d_]*))|                                                     # out streams
          (?:\s*^def\s+(\w[\w\d_\[\],]*)\s*(?:(?:\((.*)\))|(?::\s*([\w\d_\[\]]*)))?\s*:=)  # defs
        )
      ///gm
      while (result = regex.exec(source)) isnt null
        # group 1: comment
        # group 2: annotation
        # group 3: in stream name
        # group 4: in stream type
        # (group 5: out stream name)
        # group 5: def name
        # group 6: def function params
        # group 7: def type
        comment = result[1]
        if isSet(comment)
          comment = comment.replace(/#/gm, "")
            .replace(/(?=\n(?!```))/gm, " ")
            .replace(/[ \t]+/gm, " ")
            .replace(/[ ]+/gm, " ")
            .replace(/\n /gm, "\n")
            .trim()
        annotation = result[2]
        inName = result[3]
        inType = result[4]
        # outName = result[5]
        defName = result[5]
        defParams = result[6]
        defType = result[7]
        if isSet(inName) and inName.startsWith(name)
          suggestions.push(@createInSuggestion(inName, inType, comment, annotation))
        # else if isSet(outName) and outName.startsWith(name)
        #   suggestions.push(@createOutSuggestion(outName, comment, annotation))
        else if isSet(defName) and isSet(defParams) and defName.startsWith(name)
          suggestions.push(@createDefFunctionSuggestion(defName, defParams, comment, annotation))
        else if isSet(defName) and defName.startsWith(name)
          suggestions.push(@createDefVarSuggestion(defName, defType, comment, annotation))
      return suggestions
