'use babel'

$ = jQuery = require('jquery')

import TeSSLaFileScanner from './tessla-file-scanner.js'

export default class TeSSLaFunctionsSidebar {

  constructor( emitter ) {
    // store project global emitter
    this.emitter = emitter

    // set up sidebar
    var $resizer      = $('<div class="resizer"></div>')

    // create the C list stuff
    var $headline1    = $('<h2>C functions from C sources</h2>')
    this.$listC       = $('<ul class="list-c-function"></ul>')
    this.$listC.append( $('<li class="hint">No functions found</li>') )

    // create the TeSSLa list stuff
    var $headline2    = $('<h2>Missing C functions from TeSSLa sources</h2>')
    this.$listTeSSLa  = $('<ul class="list-tssl-functions"></ul>')
    this.$listTeSSLa.append( $('<li class="hint">No functions found</li>') )

    // create a wrapper element
    this.$wrapper     = $('<div id="tessla-functions-sidebar"></div>')

    // put all things together
    this.$wrapper.append($resizer)
    this.$wrapper.append($headline1)
    this.$wrapper.append(this.$listC)
    this.$wrapper.append($headline2)
    this.$wrapper.append(this.$listTeSSLa)

    // now put wrapper into an own bottom panel
    atom.workspace.addRightPanel({
      item:     this.$wrapper.get(0),
      visible:  true,
      priority: -100
    })

    // store needed elements
    this.$panel = this.$wrapper.parent()

    // emit event that functions sidebar has been created
    this.emitter.emit('created-functions-sidebar', this.$panel)

    // add emitter listeners
    this.onShow = this.onShow.bind(this)
    this.onHide = this.onHide.bind(this)
    this.onToggle = this.onToggle.bind(this)
    this.onUpdate = this.onUpdate.bind(this)
    this.onMouseDown = this.onMouseDown.bind(this)
    this.onMouseMove = this.onMouseMove.bind(this)
    this.onMouseUp = this.onMouseUp.bind(this)

    this.emitter.on('show-functions-sidebar',   this.onShow)
    this.emitter.on('hide-functions-sidebar',   this.onHide)
    this.emitter.on('toggle-functions-sidebar', this.onToggle)
    this.emitter.on('update-functions-sidebar', this.onUpdate)
    this.emitter.on('active-project-changed',   this.onUpdate)

    // bind events to resizer and document
    $resizer.mousedown(this.onMouseDown)
    $(document).mousemove(this.onMouseMove)
    $(document).mouseup(this.onMouseUp)
  }

  onMouseDown(event) {
    // rememer the mousedown position
    this.mousedown  = true
    this.mousedownX = event.pageX
    this.originalW  = this.$wrapper.width()

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseUp(event) {
    this.mousedown  = false

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseMove(event) {
    if (!this.mousedown) {
      return
    }

    // set new width
    this.$wrapper.width(this.originalW + this.mousedownX - event.pageX)

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onShow() {
    this.$panel.animate({
      width: 'show'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onHide() {
    this.$panel.animate({
      width: 'hide'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onToggle() {
    this.$panel.animate({
      width: 'toggle'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onElementClicked(functionElement, event) {
    // extract information
    var lineCol     = functionElement.children().eq(3).text()
    lineCol         = lineCol.substr(1, lineCol.length - 2).split(':')

    var line        = parseInt(lineCol[0]) - 1
    var col         = parseInt(lineCol[1])

    var file        = functionElement.children().eq(4).text()

    // open the file and set cursor to the correct position
    var currentFile = atom.workspace.getActiveTextEditor().getPath()
    var projectPath = atom.project.relativizePath(currentFile)[0]

    var splitVar    = file.substr(file.length - 2) == '.c' ? 'left' : 'right'

    atom.workspace.open(projectPath + '/' + file, {split: splitVar, searchAllPanes: true}).then((editor) => {
      editor.setCursorBufferPosition([line, col])
    })

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onCreateTestCaseClicked(functionElement, event, projectPath) {
    // get function and file name
    var functionName  = functionElement.children().eq(2).text()
    var fileName      = functionElement.children().eq(4).text()

    // get tessla files
    var tesslaFile    = require('scan-folder')(projectPath, '.tessla', true, {
      dotFolder:  false,
      dotFiles:   false,
      modules:    false
    })[0]

    // get self reference
    var self          = this

    atom.workspace.open(tesslaFile, {split: 'right', searchAllPanes: true}).then((editor) => {
      // first set cursor position to the end
      editor.setCursorBufferPosition([editor.getLineCount(), 0])

      // next craft text that should be inserted
      var text = '\n--Inserted test case automatically in the first tessla file that was found\ndefine calls_' + functionName + ' : Events<Unit> := function_calls("' + functionName + '")'

      // try to insert text into file. If everything worked update sidebar
      if ( editor.insertText(text, {select: true, autoIndent: true}) ) {
        // save editor
        editor.save()
      } else {
        // something will happen here
      }
    })

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onUpdate({projectPath, outputDir, binaryName}) {
    // do not update if the sidebar is hidden
    // if (this.$wrapper.is(':hidden')) {
    //   return
    // }

    // get list of all C files and the tessla file
    var sf      = require('scan-folder')
    var config  = {
      dotfolder: false, // no hidden folders
      dotfiles: false,  // no hidden files
      modules: false    // no module contents
    }

    var cFiles          = sf(projectPath, '.c', true, config)
    var tesslaFiles     = sf(projectPath, '.tessla', true, config)

    // get array with c functions and tessla functions
    var cFunctions      = []
    var tesslaFunctions = []
    var cFuncNames      = {}

    // empty lists
    this.$listC.empty()
    this.$listTeSSLa.empty()

    // get all C functions form all c files
    cFiles.forEach((file) => {
      // first fetch all c function from the current file
      var functions = TeSSLaFileScanner.fetchCFunctions({file: file, projectPath: projectPath})

      // merge all cFunctions from all files together
      cFunctions = cFunctions.concat(functions)

      // add a list item for each function
      functions.forEach((cFunction) => {
        // create the current list element
        var $listElement    = $('<li>')
        var $testCaseButton = $('<button class="ion-plus-circled"></button>')
        var $indicator      = $('<span>f(x)</span>')
        var $name           = $('<span>' + cFunction.functionName + '</span>')
        var $filePath       = $('<span>' + cFunction.fileName + '</span>')
        var $occurence      = $('<span>(' + cFunction.occurrence + ')</span>')
        var $cb             = $('<div class="tessla-cb"></div>')

        // put all stuff together
        $listElement.append($testCaseButton)
        $listElement.append($indicator)
        $listElement.append($name)
        $listElement.append($occurence)
        $listElement.append($filePath)
        $listElement.append($cb)
        this.$listC.append($listElement)

        // add click listener to listElement
        var self = this
        $listElement.click(function(event) {
          self.onElementClicked($(this), event)
        })

        // add click listener to button
        $testCaseButton.click(function(event) {
          self.onCreateTestCaseClicked($listElement, event, projectPath)
        })
      })
    })

    // next iterate over each TeSSLa file
    tesslaFiles.forEach((file) => {
      // first fetch all C function from the current TeSSLa file
      var functions = TeSSLaFileScanner.fetchCFunctionsFromTeSSLaFile({file: file, projectPath: projectPath})

      // remember TeSSLa functions
      tesslaFunctions = tesslaFunctions.concat(functions)

      // add a list item for list element
      functions.forEach((func) => {
        // create the current list element
        var $listElement  = $('<li>')
        var $indicator    = $('<span class="tssl">f(x)</span>')
        var $name         = $('<span>' + func + '</span>')
        var $filePath     = $('<span></span>')
        var $cb           = $('<div class="tessla-cb"></div>')

        $listElement.append($indicator)
        $listElement.append($name)
        $listElement.append($filePath)
        $listElement.append($cb)
        this.$listTeSSLa.append($listElement)
      })
    })

    tesslaFunctions.forEach((tsslFunc) => {
      cFunctions.forEach((cFunc) => {
        // get names ans paths of files
        var cFnName = cFunc.functionName
        var tFnName = tsslFunc

        cFuncNames[cFnName] = cFnName

        // var cFnPath = cFunc.fileName
        // var tFnPath = tsslFunc.fileName

        // test if function is in both lists available
        //if ( cFnName == tFnName && cFnPath == tFnPath ) {
        if ( cFnName == tFnName ) {

          // get element in list to give new color
          $.each(this.$listC.find('li'), function(key, value) {
            // get the name and the path of the current object
            var name = $(value).children().eq(2).text()
            // Attention: The path is needed when syntax as "main.c:fn" is accepted
            // Now we only check if the name of the function is equal
            //var path = $(value).children().eq(4).text()

            //if (name == cFnName && cFnPath == path) {
            if (name == cFnName) {
              // mark function as logged
              $(value).children().eq(1).addClass('tssl-logged')

              // remove test case button from element
              //var buttonWidth = $(value).children().eq(0).outerWidth(false)
              //$(value).children().eq(0).remove()

              // add a place holder to none clickable element
              //var placeholder = $('<div class='placeholder'></div>')
              //placeholder.width(buttonWidth)
              //$(value).prepend(placeholder)
            }
          })

          // last we have to hide the other elements
          $.each(this.$listTeSSLa.find('li'), function(key, value) {
            // get the name and the path of the current object
            var name = $(value).children().eq(1).text()

            // see above why we made a command from the following lines
            //var path = $(value).children().eq(2).text()
            //if (name == cFnName && cFnPath == path) {

            if (name == cFnName) {
              // remove the list element form the sidebar
              $(value).remove()
            }
          })
        }
      })
    })

    // append place holders to list if there are no files
    if ( this.$listC.children().length == 0 ) {
      this.$listC.append( $('<li class="hint">No functions found</li>') )
    }

    if ( this.$listTeSSLa.children().length == 0 ) {
      this.$listTeSSLa.append( $('<li class="hint">No functions found</li>') )
    }

    // define array difference function
    Array.prototype.diff = function(a) {
      return this.filter(function(i) {return a.indexOf(i) < 0;});
    };

    // create array from object
    var unusedFunctions  = []
    for (var key in cFuncNames) {
      unusedFunctions.push(key)
    }

    // get differences
    var difference = tesslaFunctions.diff(unusedFunctions)

    // distribute difference to all emitter listeners
    this.emitter.emit('distribute-unsued-functions', {
      unusedFunctions:  difference,
      tesslaFile:       tesslaFiles
    })
  }
}
