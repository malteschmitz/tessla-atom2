'use babel'

import { Range, Point } from 'atom'

export default class TeSSLaViewManager {

  constructor(emitter) {
    this.emitter = emitter

    // an array of markers added to the text editor
    this.tesslaMarkers              = []
    this.tesslaUnsedFunctionMarkers = []
    this.tesslaTooltipDecorations   = []

    // set tool-bar buttons object to null
    this.btns = null

    // bind self reference to methods
    this.onHighlightUnusedFunctions = this.onHighlightUnusedFunctions.bind(this)
    this.onHideErrorMarkers         = this.onHideErrorMarkers.bind(this)
    this.highlightTeSSLaError       = this.highlightTeSSLaError.bind(this)

    // set listeners
    this.emitter.on('distribute-unused-functions',    this.onHighlightUnusedFunctions)
    this.emitter.on('cursor-changed-in-file',         this.onHideErrorMarkers)
    this.emitter.on('distribute-tool-bar-buttons',    (btns) => {
      this.btns = btns
    })
  }

  showNoProjectNotification() {
    // show notification to user
    const message = 'There is no active project in your workspace. Open and activate at least one file of the project you want to compile and run in your workspace.'

    // show notification
    atom.notifications.addError('Unable to compile and run C code', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showNoCompilableCFilesNotification() {
    // show notification to user
    const message = 'There are no C files to compile in this project. Create at least one C file in this project containing a main function to build a runable binary.'

    // show notification
    atom.notifications.addError('Unable to compile C files', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-c-error-text', message + '\n')
  }

  showNoCBinaryToExecuteNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There is no C binary in the build directory which can be executed. You first have to build your C code to generate a binary.'

    // show notification
    atom.notifications.addError('Unable to run binary', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-c-error-text', message + '\n')
  }

  showNoValidClangNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'The clang compiler specified in your settings pane is not valid. The compiler does not seem to exist. Please make sure to set the correct path to your clang compiler.'

    // show notification
    atom.notifications.addError('Unable to find clang', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showNoLibInstrumentFunctionsSONotification() {
    // set up a message variable containing the text shown to the user
    const message = 'The libInstrumentFunctions.so specified in your settings pane is not valid. The library does not seem to exist. Please make sure to set the correct path to your library.'

    // show notification
    atom.notifications.addError('Unable to find libInstrumentFunctions.so', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showNoValidTeSSLaCompilerNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'The TeSSLa compiler specified in your settings pane is not valid. The compiler does not seem to exist. Please make sure to set the correct path to your compiler.'

    // show notification
    atom.notifications.addError('Unable to find TeSSLa compiler', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showNoTeSSLaServerFoundNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'The TeSSLa server specified in your settings pane is not valid. The server does not seem to exist. Please make sure to set the correct path to your TeSSLa server.'

    // show notification
    atom.notifications.addError('Unable to find TeSSLa server', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showNotSetUpSplitViewNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There are no ".tessla" and ".c" files to put into split view in the current project. Please open at least one file of your project and activate it in workspace to properly set up the split view. The split view can be set up by right click onto your source file in the text editor and select "Set up TeSSLa split view" in the context menu.'

    // show notification
    atom.notifications.addWarning('Could not set up the split view', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-warning-text', message + '\n')
  }

  showNoTeSSLaJSONFoundNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'No TeSSLa JSON file found!'

    // show notification
    atom.notifications.addError('Unable to find TeSSLa JSON file', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showNoActiveProjectForSplitViewNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'No Project currently active. To set up the split view at least one file should be active for setting up the split view'

    // show notification
    atom.notifications.addWarning('Could not set up the split view', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-warning-text', message + '\n')
  }

  showNoValidOptNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'The opt binary specified by your clang path in the settings pane is not valid. The opt binary does not seem to exist. Please make sure to set the correct path to your clang compiler.'

    // show notification
    atom.notifications.addWarning('Unable to find opt', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  showCurrentlyRunningProcessNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There is a process that is currently running. A new action can only be performed if there is no action currently running.'

    // show notification
    atom.notifications.addWarning('Unable to perform action', {
      detail: message
    })

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message + '\n')
  }

  onHighlightUnusedFunctions({unusedFunctions, tesslaFile}) {
    // console.log('TeSSLaController.onHighlightUnusedFunctions()', unusedFunctions)

    // get editor that contains the tessla file
    var editors     = atom.workspace.getTextEditors()
    var editorFile  = null

    editors.forEach((editor) => {
      if (editor.getPath() == tesslaFile) {
        editorFile = editor
      }
    })

    // if the editor exists
    if (editorFile) {
      // remove current markers
      this.tesslaUnsedFunctionMarkers.forEach((marker) => {
        marker.destroy()
      })
      this.tesslaUnsedFunctionMarkers = []

      // get editor content
      var text = editorFile.getText()

      // create line counter variable
      var lineCounter = 0

      // read content line by line
      text.split('\n').forEach((line) => {

        // look for function_calls
        unusedFunctions.forEach((func) => {
          var lookupText = 'function_calls("' + func + '")'
          var idx = line.indexOf(lookupText)

          // if there were a match
          if (idx != -1) {
            // create range
            var range = new Range(
              new Point(lineCounter, idx),
              new Point(lineCounter, idx + lookupText.length)
            )

            // create marker
            var marker = editorFile.markBufferRange(range)
            this.tesslaUnsedFunctionMarkers.push(marker)

            // decorate marker
            var decoration = editorFile.decorateMarker(marker, {
              type:   'highlight',
              class:  'tessla-unused-function'
            })
          }
        })

        lineCounter++
      })
    }
  }

  highlightTeSSLaError({error, file}) {
    // first parse error
    var regex = /\b(ParserError)\(\(([\s\,0-9\-]+)\)\:\s(.*)\)/g

    // get matches
    var match = regex.exec(error)

    console.log(match)

    // if there were matches then highlight
    if (match) {
      // remove old markers
      this.tesslaMarkers.forEach((marker) => { marker.destroy() })
      this.tesslaMarkers            = []
      this.tesslaTooltipDecorations = []

      // extract information
      var type      = match[1]
      var location  = match[2]
      var text      = match[3]

      // next get editor
      atom.workspace.open(file, {
        split: 'right',
        searchAllPanes: true
      }).then((editor) => {
        // create marker
        var start   = (location.split(' - ')[0]).split(',')
        var end     = (location.split(' - ')[1]).split(',')

        start       = new Point(start[0] - 1, start[1] - 1)
        end         = new Point(  end[0] - 1,   end[1] - 1)

        // set cursor to start position
        editor.setCursorBufferPosition(start)
        editor.scrollToCursorPosition()

        // create range object and markers
        var range   = new Range(start, end)
        var marker  = editor.markBufferRange(range)

        // remember marker
        this.tesslaMarkers.push(marker)

        // next create decoration
        var decoration = editor.decorateMarker(marker, {
          type:   'highlight',
          class:  'tessla-syntax-error'
        })

        var tt      = document.createElement('div')
        var ttLabel = document.createElement('span')
        var ttText  = document.createElement('span')

        ttLabel.textContent = 'error'
        ttText.textContent  = text

        ttLabel.classList.add('error-label')
        tt.appendChild(ttLabel)
        tt.appendChild(ttText)

        var tooltip = editor.decorateMarker(marker, {
          type:     'overlay',
          class:    'tessla-syntax-tooltip',
          item:     tt,
          position: 'tail'
        })

        // remember decoration for later
        this.tesslaTooltipDecorations.push(tooltip)

        // add a gutter to the opened file
        var gutter = editor.gutterWithName('tessla-error-gutter')
        if (!gutter) {
          gutter = editor.addGutter({
            name:     'tessla-error-gutter',
            priority: 1000,
            visible:  true
          })
        }

        var gutterDot = gutter.decorateMarker(marker, {
          type:   'gutter',
          class:  'tessla-syntax-dot'
        })
      })
    }
  }

  onHideErrorMarkers(event) {
    //  skip the rest of this method if there are no markers
    if (this.tesslaMarkers.length == 0) {
      return
    }

    // destroy each marker
    this.tesslaTooltipDecorations.forEach((decoration) => {
      decoration.destroy()
    })

    // remove markers from array
    this.tesslaTooltipDecorations = []
  }

  disableButtons() {
    this.btns['BuildAndRunCCode'].setEnabled(false)
    this.btns['BuildCCode'].setEnabled(false)
    this.btns['RunCCode'].setEnabled(false)
    this.btns['BuildAndRunProject'].setEnabled(false)
  }

  enableButtons() {
    this.btns['BuildAndRunCCode'].setEnabled(true)
    this.btns['BuildCCode'].setEnabled(true)
    this.btns['RunCCode'].setEnabled(true)
    this.btns['BuildAndRunProject'].setEnabled(true)
  }

  enableStopButton() {
    this.btns['Stop'].setEnabled(true)
  }

  disableStopButton() {
    this.btns['Stop'].setEnabled(false)
  }

  removeTeSSLaSourceMarkers() {
    this.tesslaMarkers.forEach((marker) => { marker.destroy() })
    this.tesslaMarkers            = []
    this.tesslaTooltipDecorations = []
  }
}
