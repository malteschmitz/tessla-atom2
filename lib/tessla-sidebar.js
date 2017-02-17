'use babel'

$ = jQuery = require('jquery')

import TeSSLaFileScanner from './tessla-file-scanner.js'

export default class TeSSLaSidebar {

  constructor( emitter ) {
    // store project global emitter
    this.emitter = emitter

    // set up sidebar
    var $resizer        = $('<div class="resizer"></div>')

    // create the C list stuff
    var $headline1      = $('<h2>C functions from C sources</h2>')
    this.$listC         = $('<ul class="list-c-function"></ul>')
    this.$listC.append( $('<li class="hint">No functions found</li>') )

    // create the TeSSLa list stuff
    var $headline2      = $('<h2>Missing C functions from TeSSLa sources</h2>')
    this.$listTeSSLa    = $('<ul class="list-tssl-functions"></ul>')
    this.$listTeSSLa.append( $('<li class="hint">No functions found</li>') )

    // create a wrapper element
    this.$functionsView = $('<div id="tessla-sidebar"></div>')
    this.$sidebar       = $('<div id="tessla-sidebar-wrapper"></div>')

    // put all things together
    this.$functionsView.append($headline1)
    this.$functionsView.append(this.$listC)
    this.$functionsView.append($headline2)
    this.$functionsView.append(this.$listTeSSLa)

    // create table view
    this.$tableView     = $('<div id="tessla-table-view"></div>')

    var $vertResizer    = $('<div class="vertical-resizer"></div>')
    var $headline3      = $('<h2>Formatted TeSSLa output</h2>')
    this.$listOutputs   = $('<ul class="list-formatted-output"></ul>')
    this.$listOutputs.append( $('<li class="hint">No output available</li>') )

    this.$tableView.append($headline3)
    this.$tableView.append(this.$listOutputs)

    // put two elements into sidebar
    this.$sidebar.append($resizer)
    this.$sidebar.append(this.$functionsView)
    this.$sidebar.append($vertResizer)
    this.$sidebar.append(this.$tableView)

    // now put wrapper into an own bottom panel
    atom.workspace.addRightPanel({
      item:     this.$sidebar.get(0),
      visible:  true,
      priority: -100
    })

    // store needed elements
    this.$panel = this.$sidebar.parent()

    // emit event that functions sidebar has been created
    this.emitter.emit('created-sidebar', this.$panel)

    // add emitter listeners
    this.onShow                 = this.onShow.bind(this)
    this.onHide                 = this.onHide.bind(this)
    this.onToggle               = this.onToggle.bind(this)
    this.onUpdate               = this.onUpdate.bind(this)
    this.onMouseDownColResizer  = this.onMouseDownColResizer.bind(this)
    this.onMouseDownRowResizer  = this.onMouseDownRowResizer.bind(this)
    this.onMouseMove            = this.onMouseMove.bind(this)
    this.onMouseUp              = this.onMouseUp.bind(this)
    this.onFormatOutput         = this.onFormatOutput.bind(this)
    this.onToggleOutputSubList  = this.onToggleOutputSubList.bind(this)

    this.emitter.on('show-sidebar',           this.onShow)
    this.emitter.on('hide-sidebar',           this.onHide)
    this.emitter.on('toggle-sidebar',         this.onToggle)
    this.emitter.on('update-sidebar',         this.onUpdate)
    this.emitter.on('active-project-changed', this.onUpdate)
    this.emitter.on('format-tessla-output',   this.onFormatOutput)

    // bind events to resizer and document
    $resizer.mousedown(this.onMouseDownColResizer)
    $vertResizer.mousedown(this.onMouseDownRowResizer)
    $(document).mousemove(this.onMouseMove)
    $(document).mouseup(this.onMouseUp)
  }

  onMouseDownRowResizer(event) {
    this.mouseDownRowResizer  = true
    this.mousedownY           = event.pageY
    this.originalH            = this.$functionsView.outerHeight()

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseDownColResizer(event) {
    // rememer the mousedown position
    this.mouseDownColResizer  = true
    this.mousedownX           = event.pageX
    this.originalW            = this.$sidebar.width()

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseUp(event) {
    this.mouseDownColResizer = false
    this.mouseDownRowResizer = false

    // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseMove(event) {
    if (this.mouseDownColResizer) {
      // set new width
      this.$sidebar.width(this.originalW + this.mousedownX - event.pageX)

      // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
      event.preventDefault()
      event.stopPropagation()
    }

    if (this.mouseDownRowResizer) {
      // calc new height
      var newHeight     = this.originalH - this.mousedownY + event.pageY
      var sidebarHeight = this.$sidebar.height()

      if (newHeight < sidebarHeight - 150) {
        // set new height
        this.$functionsView.outerHeight(newHeight)

        // get new height ffor table view
        this.$tableView.outerHeight(sidebarHeight - newHeight)
      }

      // prevent slowing atom down by propagating event throuth DOM and prevent default event beahavior
      event.preventDefault()
      event.stopPropagation()
    }
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
    // if (this.$functionsView.is(':hidden')) {
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

    // resize elements
    this.resizeElements()

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

  resizeElements() {
    // get height of functions view
    var heightFunctionsView = this.$functionsView.outerHeight()
    var heightSidebar       = this.$sidebar.height()

    // if max height of functions view is not reached
    if (heightFunctionsView < heightSidebar - 150) {
      // make table view fill space
      this.$tableView.outerHeight(heightSidebar - heightFunctionsView)
    }

    // if functions view is higher than max value
    else {
      // set functions view onto max value
      this.$functionsView.outerHeight(heightSidebar - 150)
      // set table view to difference
      this.$tableView.outerHeight(150)
    }
  }

  onToggleOutputSubList($element) {

    // change arrow icon of list element
    var $arrow = $('span:first', $element)

    // toggle arrow classes after animation is done
    if ($arrow.hasClass('ion-chevron-right')) {
      $arrow.removeClass('ion-chevron-right')
      $arrow.addClass('ion-chevron-down')

      // make element active
      $element.siblings().removeClass('active')
      $element.addClass('active')
    } else if ($arrow.hasClass('ion-chevron-down')) {
      $arrow.removeClass('ion-chevron-down')
      $arrow.addClass('ion-chevron-right')

      $element.removeClass('active')
    }

    // now show sublist
    $element.find('ul').animate({
      height: 'toggle'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onFormatOutput({output, startTime}) {
    // first build regex
    var regex = /(.+)@(.+):(.+)/g

    // array containing formatted lines
    var formatted = {}

    // next loop over matches
    output.forEach((line) => {
      // get the match
      var match

      // loop over each match for the current line
      do {
        match = regex.exec(line)

        // if there was a match log groupes
        if (match) {
          // format timestamp
          var date    = new Date(parseFloat(match[2]) * 1000)
          // get components
          var hours   = date.getHours() < 10 ? '0' + date.getHours() : date.getHours()
          var minutes = date.getMinutes() < 10 ? '0' + date.getMinutes() : date.getMinutes()
          var seconds = date.getSeconds() < 10 ? '0' + date.getSeconds() : date.getSeconds()
          // put all things together
          var dateString = hours + ':' + minutes + ':' + seconds + '.' + date.getMilliseconds()

          // push values into formatted array
          if (formatted.hasOwnProperty(match[1])) {
            formatted[match[1]].push({
              time: parseFloat(match[2]),
              formattedTime: dateString,
              value: match[3]
            })
          } else {
            formatted[match[1]] = [{
              time: parseFloat(match[2]),
              formattedTime: dateString,
              value: match[3]
            }]
          }
        }
      } while (match)
    })

    // clear list
    this.$listOutputs.empty()

    // remember self reference
    var self = this
    var countProps = 0

    // now run over each property and first sort elements and then add elements to view
    for (var key in formatted) {
      // sort array by timestamp
      formatted[key].sort((a, b) => {
        return a.time - b.time
      })

      // ok and the last step will be inserting values into list
      var $icon    = $('<span class="ion-chevron-right"></span>')
      var $label   = $('<span>' + key + '</span>')
      var $entry   = $('<li>')
      var $sublist = $('<ul>')

      formatted[key].forEach((element) => {
        // create new list element
        var $listElement = $('<li>')
        $listElement.append($('<span>' + element.formattedTime + '</span>'))
        $listElement.append($('<span>' + element.value + '</span>'))
        $listElement.append($('<div class="tessla-cb"></div>'))

        // append element to sublist
        $sublist.append($listElement)
      })

      // set listener to list element
      $label.click(function(event) {
        self.onToggleOutputSubList($(this).parent())
      })

      $icon.click(function(event) {
        self.onToggleOutputSubList($(this).parent())
      })

      $entry.append($icon)
      $entry.append($label)
      $entry.append($('<div class="tessla-cb"></div>'))
      $entry.append($sublist)
      this.$listOutputs.append($entry)

      // increase property counter
      countProps++
    }

    if ( countProps == 0 ) {
      this.$listOutputs.append( $('<li class="hint">No output available</li>') )
    }

    // now resize elements
    this.resizeElements()
  }
}
