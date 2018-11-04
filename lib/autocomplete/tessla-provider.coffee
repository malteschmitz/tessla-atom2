
path = require "path"
fs = require "fs"
showdown = require "showdown"
converter = new showdown.Converter()

module.exports=
  class TeSSLaProvider
    selector: "tessla"
    disableForSelector: ".source.tessla .comment"
    inclusionPriority: 1
    excludeLowerPriority: true
    suggestionPriority: 2
    filterSuggestions: true


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
      regex = /(?:(?:#.*\s+)*)(?:@.+\s+)?(?:def|in)\s+(\w[\d\w_]*)/gm
      while (result = regex.exec(source)) isnt null
        #group 1: symbol
        symbol = result[1]
        if symbol.startsWith(name)
          suggestions.push({ text: symbol, type: "variable" })
      return suggestions

    findSymbolsFromLib: (source, name) =>
      suggestions = []
      regex = /((?:#.*\s+)+)(?:@.+\s+)?(?:def)\s+(\w[\d\w_]*)/gm
      while (result = regex.exec(source)) isnt null
        #group 1: comment
        #group 2: defined symbol
        comment = result[1].split("#").join(" ").replace(/ +(?= )/g, "").trim()
        symbol = result[2]
        if symbol.startsWith(name)
          suggestions.push({ text: symbol, type: "function", description: comment })
      return suggestions
