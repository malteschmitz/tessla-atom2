path = require 'path'
fs = require 'fs'

module.exports=
  class FileManager

    @collectCFunctionsFromSourceFile: ({ sourceFile, projectPath }) ->
      namesAssoc = {}
      names = []

      fileExtension = path.extname sourceFile
      fileLines = fs.readFileSync(sourceFile).toString().split '\n'

      if fileExtension is '.c'
        regex = ///
          (?:[a-zA-Z][_\w]*)        # ungrouped match that starts with a letter - This is the return type of the function
          (?:\s*[*]?\s+|\s+[*]\s*)  # optional an asterics for a pointer can follow
          ([a-zA-Z][_\w]*)          # followed by the match for the actual function name
          \s*                       # followed by any number of spaces
          \(                        # and finally the opening parenthesis
          ///g

        lineCnt = 0

        fileLines.forEach (line) ->
          lineCnt++

          while (match = regex.exec line)?
            f = sourceFile.replace "#{projectPath}/", ""
            func = match[1]

            namesAssoc["#{f}:#{func}"] =
              fileName: f
              functionName: func
              line: lineCnt
              column: match.index

        for key, funcs of namesAssoc
          names.push funcs

      else if fileExtension is '.tessla'
        fileLines.forEach (line) ->
          idxFnCall = line.indexOf 'function_calls("'
          idxComment = line.indexOf '--'

          onlyFunctionCall = idxFnCall isnt -1 and idxComment is -1;
          functionCallBeforeComment = idxFnCall isnt -1 and idxComment isnt -1 and idxFnCall < idxComment

          if onlyFunctionCall or functionCallBeforeComment
            functionName = line.substr idxFnCall + 'function_calls("'.length
            functionName = functionName.substr 0, functionName.indexOf '"'

            namesAssoc.functionName =
              fileName: ''
              functionName: functionName
              line: ''
              column: ''

        for key, funcs of namesAssoc
          names.push funcs

      names
