
path = require "path"

module.exports=
  isChildOf: (child, parent) ->
    if child is parent
      return no
    parentTokens = parent.split(path.sep).filter((i) -> i.length)
    childTokens = child.split(path.sep).filter((i) -> i.length)
    return parentTokens.every((t, i) -> childTokens[i] is t)

  isSet: (obj) ->
    return obj isnt null and obj isnt undefined

  isFunction: (fct) ->
    return fct and {}.toString.call(fct) is "[object Function]"
