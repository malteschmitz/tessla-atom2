
{DEBUG} = require("./constants")

module.exports=
  class Logger
    @err: (args...) ->
      if DEBUG
        for arg in args
          console.error("ERR: ", arg)

    @log: (args...) ->
      if DEBUG
        for arg in args
          console.log(arg)

    @print: (args...) ->
      for arg in args
        console.log(arg)
