scanFolder = require "scan-folder"

module.exports=
  class SidebarViewElement

    constructor: ({ name: name, file: file, line: line, column: col, observed: o, exists: e, viewManager: v }) ->
      observed = o ? no
      exists = e ? no

      itemWrapper = document.createElement "li"
      itemWrapper.classList.add "list-item", "function-wrapper"

      addBtn = document.createElement "a"
      addBtn.classList.add "ion-plus-circled"

      fxLabel = document.createElement("span");
      fxLabel.classList.add "text-info" if observed
      fxLabel.classList.add "text-success" if not observed and exists

      unless exists or observed
        fxLabel.classList.add "text-error"
        addBtn.classList.add "icon-invisible", "cursor-default"

      fxLabel.innerHTML = "f(x)"

      fxName = document.createElement "span"
      fxName.innerHTML = name

      itemWrapper.appendChild addBtn
      itemWrapper.appendChild fxLabel
      itemWrapper.appendChild fxName

      unless line is "" or col is ""
        lineCol = document.createElement "span"
        lineCol.classList.add "align-right", "itshape", "subtle"
        lineCol.innerHTML = "#{file} (l#{line}:c#{col})"
        itemWrapper.appendChild lineCol

      @element = itemWrapper

      addBtn.addEventListener "click", (event) =>
        @onAddTest
          functionName: name
          projectPath: v.activeProject.projPath
        , event


    onClick: (self) ->
      if self.classList.contains "collapsed"
        self.classList.remove "collapsed"
      else
        self.classList.add "collapsed"


    onAddTest: ({ functionName, projectPath }, event) ->
      tesslaFile = scanFolder(projectPath, ".tessla", yes,
        dotFolder: no,
        dotFiles: no,
        modules: no,
      )[0]

      atom.workspace.open(tesslaFile, { split: "right", searchAllPanes: yes }).then (editor) ->
        editor.setCursorBufferPosition [editor.getLineCount(), 0]

        text  = "\n--Inserted test case automatically in the first tessla file that was found"
        text += "\ndefine calls_#{functionName} : Events<Unit> := function_calls(\"#{functionName}\")"

        editor.save() if editor.insertText text, { select: yes, autoIndent: yes }

      event.preventDefault()
      event.stopPropagation()
