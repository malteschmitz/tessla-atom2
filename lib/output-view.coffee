OutputViewElement = require "./output-view-element"

module.exports=
  class OutputView

    constructor: (@config) ->
      @title = @config.title;
      @URI = @config.URI;

      @element = document.createElement "div"
      @element.classList.add "output-wrapper"

      toolbar = document.createElement "div"
      toolbar.classList.add "btn-toolbar"

      btnGroup = document.createElement "div"
      btnGroup.classList.add "btn-group", "float-right"

      expandBtn = document.createElement "a"
      expandBtn.classList.add "btn"
      expandBtn.innerHTML = "Expand All"

      collapseBtn = document.createElement "a"
      collapseBtn.classList.add "btn"
      collapseBtn.innerHTML = "Collapse All"

      btnGroup.appendChild expandBtn
      btnGroup.appendChild collapseBtn
      toolbar.appendChild btnGroup
      @element.appendChild toolbar

      header = document.createElement "h4"
      header.classList.add "align-center", "block", "highlight", "padding-5px"
      header.innerHTML = "Output Streams"

      @element.appendChild header

      listTree = document.createElement "ul"
      listTree.classList.add "list-tree", "has-collapsable-children"

      listWrapper = document.createElement "div"
      listWrapper.classList.add "list-wrapper"

      placeholder = document.createElement "span"
      placeholder.classList.add "placeholder"
      placeholder.innerHTML = "No functions found"

      listTree.appendChild placeholder
      listWrapper.appendChild listTree
      @element.appendChild listWrapper

      expandBtn.addEventListener "click", @onExpand
      collapseBtn.addEventListener "click", @onCollapse

    addEntry: (identifier, content) ->
      entry = new OutputViewElement identifier, content
      listTree = @element.getElementsByClassName("list-tree")[0]
      placeholder = listTree.querySelector ".placeholder"

      listTree.appendChild entry.element
      listTree.removeChild(placeholder) if placeholder?


    clearEntries: ->
      treeView = @element.getElementsByClassName("list-tree")[0];
      treeView.removeChild treeView.lastChild while treeView.hasChildNodes()

      placeholder = document.createElement "span"
      placeholder.classList.add "placeholder"
      placeholder.innerHTML = "No functions found";

      treeView.appendChild placeholder


    onExpand: ->
      list = @element.getElementsByClassName("list-tree")[0];
      listItems = list.children

      for item in listItems
        if item.classList.contains "list-nested-item" and item.classList.contains "collapsed"
          item.classList.remove "collapsed"

    onCollapse: ->
      list = @element.getElementsByClassName("list-tree")[0];
      listItems = list.children

      item.classList.add "collapsed" for item in listItems when item.classList.contains "list-nested-item"


    getTitle: ->
      @title


    getURI: ->
      @URI


    getDefaultLocation: ->
      "right"


    getAllowedLocations: ->
      ["right", "center", "left"]


    destroy: ->
      @element.remove()


    update: (output) ->
      console.log(output);

      regex = /(.+)@(.+):(.+)/g
      formatted = {}

      output.forEach (line) ->
        while (match = regex.exec line)?
          if match?

            dateString = ""
            if parseFloat(match[2]) is 0
              dateString = "initially";
            else
              date = new Date parseFloat(match[2]) * 1000
              hours = if date.getHours() < 10 then "0#{date.getHours()}" else date.getHours()
              minutes = if date.getMinutes() < 10 then "0#{date.getMinutes()}" else date.getMinutes()
              seconds = if date.getSeconds() < 10 then "0#{date.getSeconds()}" else date.getSeconds()
              dateString = "#{hours}:#{minutes}:#{seconds}.#{date.getMilliseconds()}"

            if match[1] of formatted
              formatted[match[1]].push
                time: parseFloat(match[2])
                formattedTime: dateString
                value: match[3]
            else
              formatted[match[1]] = [
                time: parseFloat(match[2])
                formattedTime: dateString
                value: match[3]
              ]

      @clearEntries()

      for key, value of formatted
        value.sort (a, b) -> a.time - b.time
        @addEntry key, value
