
path = require "path"
fs = require "fs"
showdown = require "showdown"
converter = new showdown.Converter()

module.exports=
  class TeSSLaAutocompleter
    constructor: ->
      @selector = "tessla"
      @disableForSelector = "comment"
      @inclusionPriority = 1
      @excludeLowerPriority = yes
      @suggestionPriority = 2
      @filterSuggestions = yes


    getSuggestions: (options) =>
      return new Promise((resolve, reject) =>
        editor = options.editor
        prefix = options.prefix
        @findMatchingSuggestions(prefix, editor)
          .then((suggestions) => resolve(suggestions))
      )


    findMatchingSuggestions: (prefix, editor) =>
      return new Promise((resolve, reject) =>
        libFile = path.join(path.dirname(editor.getPath()), "stdlib.tessla")
        fs.readFile(libFile, { encoding: "utf-8" }, (err, data) =>
          if err is null or err is undefined
            libSymbols = @findSymbolsFromLib(data, prefix)
            fileSymbols = @findSymbolsFromFile(editor.getText(), prefix)
            suggestions = fileSymbols.concat(libSymbols)
            resolve(suggestions)
        )
      )


    findSymbolsFromFile: (source, name) =>
      suggestions = []
      regex = /((?:#.*\s+)*)(?:@.+\s+)?^(?:def|in)\s+(\w[\d\w_]*)/gm
      while (result = regex.exec(source)) isnt null
        #group 1: comment
        #group 1: symbol
        comment = result[1].split("#").join(" ").replace(/ +(?= )/g, "").trim()
        symbol = result[2]
        if symbol.startsWith(name)
          suggestions.push({ text: symbol, type: "variable", description: comment })
      return suggestions


    findSymbolsFromLib: (source, name) =>
      suggestions = []
      # regex = /((?:#.*\s+)+)(?:@.+\s+)?(?:def)\s+(\w[\d\w_]*)/gm
      regex = /((?:#.*\s+)+)(?:@.+\s+)?(?:def)\s+((\w[\d\w_]*)\s*(?:\[[\w,]*\])?(?:\((.*)\)\s*)):=/gm
      while (result = regex.exec(source)) isnt null
        #group 1: comment
        #group 2: signature
        #group 3: defined symbol
        #group 4: params
        comment = result[1].split("#").join(" ").replace(/ +(?= )/g, "").trim()
        signature = result[2]
        symbol = result[3]
        params = result[4].replace(/\s/g, "").split(",")
        if symbol.startsWith(name)
          args = []
          i = 1;
          for param in params
            if param.indexOf(":") >= 0
              args.push("${#{i++}:#{param.replace(":", ": ")}}")
          suggestions.push({
            text: symbol,
            displayText: signature,
            snippet: "#{symbol}(#{args.join(", ")})",
            type: "function",
            description: comment
          })
      return suggestions
