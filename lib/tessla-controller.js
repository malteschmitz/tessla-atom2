'use babel'

import path from 'path'
import { Range, Point } from 'atom'
import scanFolder from 'scan-folder'
import TeSSLaFileManager from './tessla-file-manager.js'
import fs from 'fs'
import childProcess from 'child_process'

export default class TeSSLaController {

  sfConfig: {
    dotfolder: false, // no hidden folders
    dotfiles: false,  // no hidden files
    modules: false    // no module contents
  };

  constructor(emitter: Emitter, activeProject: TeSSLaProject, viewMgr: TeSSLaViewManager) {
    // Store project gobal emitter in own object
    this.emitter        = emitter
    this.activeProject  = activeProject
    this.viewMgr        = viewMgr
    // get a reference for the currently running process
    this.runningProcess = null

    // listen to save events or tab change events
    this.onFileSavedOrAdded         = this.onFileSavedOrAdded.bind(this)
    this.onFileChanged              = this.onFileChanged.bind(this)
    this.onNoOpenFile               = this.onNoOpenFile.bind(this)
    this.onCompileAndRunCCode       = this.onCompileAndRunCCode.bind(this)
    this.onCompileAndRunProject     = this.onCompileAndRunProject.bind(this)
    this.onBuildCCode               = this.onBuildCCode.bind(this)
    this.onRunBinary                = this.onRunBinary.bind(this)
    this.onStopRunningActiveProcess = this.onStopRunningActiveProcess.bind(this)
    this.onSetUpSplitView           = this.onSetUpSplitView.bind(this)

    this.emitter.on('file-saved',                     this.onFileSavedOrAdded)
    this.emitter.on('file-changed',                   this.onFileChanged)
    this.emitter.on('no-open-file',                   this.onNoOpenFile)
    this.emitter.on('compile-and-run-c-code',         this.onCompileAndRunCCode)
    this.emitter.on('compile-and-run-project',        this.onCompileAndRunProject)
    this.emitter.on('build-c-code',                   this.onBuildCCode)
    this.emitter.on('run-c-code',                     this.onRunBinary)
    this.emitter.on('stop-current-process',           this.onStopRunningActiveProcess)
    this.emitter.on('set-up-split-view',              this.onSetUpSplitView)
    this.emitter.on('added-text-editor-to-workspace', this.onFileSavedOrAdded)
    this.emitter.on('stop-changing-text-editor-content', () => {
      // console.log('Stop changing content of editor')
      this.emitter.emit('update-sidebar', this.activeProject)
    })
  }

  onSetUpSplitView() {
    // console.log('TeSSLaController.onSetUpSplitView()')
    // get open file
    var activeEditor = atom.workspace.getActiveTextEditor()
    if (activeEditor) {

      // get path from text editor
      var currentFile  = activeEditor.getPath()

      // check if untitled editor is open
      if (typeof currentFile === 'undefined') {
        // show notification that no project is currently open
        this.viewMgr.showNoActiveProjectForSplitViewNotification()
        // skip the rest
        return
      }

      // set up project settings
      this.activeProject.setProjPath(atom.project.relativizePath(currentFile)[0])

      // if there are no files then the split view can not be set up
      if (!this.activeProject.cFiles && !this.activeProject.tesslaFiles) {
        this.viewMgr.showNotSetUpSplitViewNotification()
        return
      }

      // first get panes and destroy them
      atom.workspace.getPanes().forEach((pane) => {
        pane.destroy()
      })

      // create two panes
      atom.workspace.getPanes()[0].splitRight()

      // add files to pane
      this.activeProject.cFiles.forEach((file) => {
        atom.workspace.open(file, {split: "left"})
      })

      this.activeProject.tesslaFiles.forEach((file) => {
        atom.workspace.open(file, {split: "right"}).then((editor) => {
          // add a gutter to each tessla file
          editor.addGutter({name: 'tessla-error-gutter', priority: 1000, visible: true})
        })
      })
    } else {
      // show notification that no project is currently open
      this.viewMgr.showNoActiveProjectForSplitViewNotification()
    }
  }

  onNoOpenFile() {
    // console.log('TeSSLaController.onNoOpenFile()')
    if ( this.activeProject.projPath != '' ) {
      // set path to empty values
      this.activeProject.clear()
      // emit new
      this.emitter.emit('active-project-changed', this.activeProject)
    }
  }

  onFileSavedOrAdded(file: string) {
    // console.log('TeSSLaController.onFileSavedOrAdded(' + file + ')')
    // get new Project path
    var newProjectPath = atom.project.relativizePath(file)[0]

    // if the new Project path is different from the current then emit signal
    // to force subscribers to update thier path
    if ( this.activeProject.projPath != newProjectPath ) {
      // set new path values
      this.activeProject.setProjPath(newProjectPath)

      // dispatch event that active project has changed
      this.emitter.emit('active-project-changed', this.activeProject)

      // setup project structure
      this.activeProject.setUpProjectStructure()
    } else {
      // emit event that updates function sidebar
      this.emitter.emit('update-sidebar', this.activeProject)
    }
  }

  onFileChanged(file) {
    //console.log('TeSSLaController.onFileChanged(' + file + ')')
    if (typeof file === 'undefined') {
      return
    }

    // get new Project path
    var newProjectPath = atom.project.relativizePath(file)[0]

    // if the new Project path is different from the current then emit signal
    // to force subscribers to update thier path
    if ( this.activeProject.projPath != newProjectPath ) {
      // set own value
      this.activeProject.setProjPath(newProjectPath)

      // and then emit to subscribers
      this.emitter.emit('active-project-changed', this.activeProject)

      //this.setUpProjectStructure()
      this.activeProject.setUpProjectStructure()
    }
  }

  saveEditors() {
    // Save all other text editors
    var activeEditor = atom.workspace.getActiveTextEditor()
    atom.workspace.getTextEditors().forEach((editor) => {
      if (typeof editor.getPath() !== 'undefined' && editor !== activeEditor) {
        editor.save()
      }
    })

    // then save currently active text editor
    if (typeof activeEditor !== 'undefined') {
      activeEditor.save()
    }
  }

  createZlogFile() {
    // craft content of zlog file
    var binName   = this.activeProject.binName
    var outputDir = this.activeProject.outputDir

    var formats = '[formats]\n'
    formats += 'variable_values = "' + atom.config.get('tessla.variableValueFormatting') + '"\n'
    formats += 'function_calls = "' + atom.config.get('tessla.functionCallFormatting') + '"\n'

    var rules = '[rules]\n'
    rules += 'variable_values_cat.DEBUG "' + 'instrumented_' + binName + '.trace"; variable_values\n'
    rules += 'function_calls_cat.DEBUG "' + 'instrumented_' + binName + '.trace"; function_calls\n'

    // first remove existing zlog
    if ( fs.existsSync(path.join(outputDir, 'zlog.conf')) ) {
      fs.unlinkSync(path.join(outputDir, 'zlog.conf'))
    }

    // then create new zlog.conf file
    fs.writeFileSync(path.join(outputDir, 'zlog.conf'), formats + rules)
  }

  onCompileAndRunCCode() {
    // skip if there is no active project!
    if ( !this.activeProject.projPath ) {
      this.viewMgr.showNoProjectNotification()
      return
    }

    // create build directory
    if ( !fs.existsSync(this.activeProject.outputDir) ) {
      fs.mkdirSync(this.activeProject.outputDir);
    }

    // Save all other text editors
    this.saveEditors()

    // Then compile C code
    this.onBuildCCode({buildAssembly: false, onSuccess: () => this.onRunBinary({})})
  }

  onCompileAndRunProject() {
    // skip if there is no active project!
    if ( !this.activeProject.projPath ) {
      this.viewMgr.showNoProjectNotification()
      return
    }

    // create build directory
    if ( !fs.existsSync(this.activeProject.outputDir) ) {
      // create directory
      fs.mkdirSync(this.activeProject.outputDir)
    }

    // create zlog file
    this.createZlogFile()

    // Save all other text editors
    this.saveEditors()

    // start compilation process
    this.onBuildCCode({                               // First compile C code into Assembly
      onSuccess: () => this.onPatchAssembly({         // then patch Assembly
        onSuccess: () => this.onBuildAssembly({       // compile patched Assembly
          onSuccess: () => this.onRunPatchedBinary({  // run patched binary
            onSuccess: () => this.onBuildTeSSLa({     // build TeSSLa code
              onSuccess: () => this.onRunTeSSLa({
                onSuccess: (lines) => {
                  //console.log(startTime)
                  // emit signal that components can update with correct output values
                  this.emitter.emit('format-tessla-output', {output: lines})
                }
              }),  // run TeSSLa server
              onError: this.viewMgr.highlightTeSSLaError
            })
          })
        })
      }),
      buildAssembly: true
    })
  }

  onPatchAssembly({onSuccess, onError}) {
    // set fallback for functions that should be instrumented
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess
    onError   = (typeof onError === 'undefined')   ? () => {} : onErro

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    // fetch all tessla files from project directory
    let instrumentArgs = []
    TeSSLaFileManager.collectCFunctionsFromSourceFile({
      sourceFile:  this.activeProject.tesslaFiles[0],
      projectPath: this.activeProject.projPath
    }).forEach(function(value, index, array) {
      instrumentArgs.push('-instrument')
      instrumentArgs.push(value)
    })

    // get vars for paths
    const projPath  = this.activeProject.projPath
    const outputDir = this.activeProject.outputDir
    const binName   = this.activeProject.binName

    // create command and args
    let command = 'docker'
    const args = [
      'run',
      '--volume',
      projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla && /usr/lib/llvm-3.8/bin/opt -load /InstrumentFunctions/libInstrumentFunctions.so -instrument_function_calls build/' + binName + '.bc ' + instrumentArgs.join(' ') + ' > build/instrumented_' +  binName + '.bc'
    ]

    // start process
    this.runningProcess = childProcess.spawn(command, args)

    // get errors
    var errors = []
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.emitter.emit('add-c-error-text', data.toString())

      // increase counter
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // craft command
      command += ' ' + args.map((arg) => {
        return (arg.charAt(0) != '-' && arg.charAt(0) != '>') ? '"' + arg + '"' : arg
      }).join(' ')

      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // react on output
      if (errors.length == 0) {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] Successfully patched Assembly from this project\n')

        // then show notifications
        atom.notifications.addSuccess('Successfully patched Assembly')

        // then resolve by passing back the command and a message
        onSuccess.call(this)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] An error occurred while patching Assembly\n')

        // then show notifications
        atom.notifications.addError('Errors while patching Assembly', {detail: errors.join('')})

        // all error callback function
        onError.call(this)
      }
    })
  }

  onBuildTeSSLa({onSuccess, onError}) {
    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess
    onError   = (typeof onError === 'undefined') ? () => {} : onError

    // skip if there are no files to compile
    if (!this.activeProject.tesslaFiles) {
      this.viewMgr.showNoCompilableTeSSLaFilesNotification()
      return
    } else if (this.activeProject.tesslaFiles.length > 1) {
      this.viewMgr.showTooMuchCompilableTeSSLaFilesNotification()
    }

    const file = this.activeProject.tesslaFiles[0]

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    // create command and args
    let command = 'docker'
    const args = [
      'run',
      '--volume',
      this.activeProject.projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla && java -jar /tessla-imdea-snapshot.jar ' +
        path.relative(this.activeProject.projPath, file).replace(/\\/g, '/')
    ]

    // create a new process
    this.runningProcess = childProcess.spawn(command, args)

    let outputs = []
    this.runningProcess.stdout.on('data', (data) => {
      outputs.push(data.toString())
    })

    let errors = []
    this.runningProcess.stderr.on('data', (data) => {
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // craft command
      command =  command + ' ' + args.map((arg) => {
        return arg.charAt(0) != '-' ? '"' + arg + '"' : arg
      }).join(' ')

      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // create strings from arrays
      let stdout = outputs.join()
      let stderr = errors.join()

      // check for compiler errors
      if (stdout.charAt(0) == '{') {
        // cut trailing comma
        //
        // Why the hell the compiler puts an trailing ',' to the string?? should
        // actually be fixed in the compiler binary not in this package!!!!
        if (stdout.charAt(stdout.length - 2) == ',') {
          stdout = stdout.slice(0, -2) + '\n'
        }

        // here we know the compilation process was successful so write content to file
        fs.writeFileSync(path.join(this.activeProject.outputDir, 'instrumented_' + this.activeProject.binName + '.tessla.json'), stdout)

        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] Successfully compiled ' + file + '\n')

        // then show notifications
        atom.notifications.addSuccess('Successfully compiled TeSSLa file')

        // remove markers from TeSSLa source code
        this.viewMgr.removeTeSSLaSourceMarkers()

        // then resolve by passing back the command and a message
        onSuccess.call(this)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] An error occurred while compiling ' + file + '\n')
        this.emitter.emit('add-tessla-error-text', stderr + stdout + '\n')

        // then show notifications
        atom.notifications.addError('Errors while compiling TeSSLa file', {detail: stderr + stdout})

        // run error callback
        onError.call(this, {error: stderr + stdout, file: file})
      }
    })
  }

  onBuildAssembly({onSuccess, onError}) {
    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess
    onError   = (typeof onError === 'unefined') ? () => {} : onError

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    let command = 'docker'
    const args = [
      'run',
      '--volume',
      this.activeProject.projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla && clang++ build/instrumented_' + this.activeProject.binName + '.bc -o build/instrumented_' + this.activeProject.binName +
        ' -lzlog -lpthread -L/usr/local/lib -L/InstrumentFunctions -lLogger'
    ]

    // create a new process
    this.runningProcess = childProcess.spawn(command, args)

    let errors = []
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.emitter.emit('add-c-error-text', data.toString())
      // increase counter
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // craft command
      command += ' ' + args.map((arg) => {
        return arg.charAt(0) != '-' ? '"' + arg + '"' : arg
      }).join(' ')

      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // react on output
      if (errors.length == 0) {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] Successfully compiled Assembly\n')

        // then show notifications
        atom.notifications.addSuccess('Successfully compiled Assembly')

        // then resolve by passing back the command and a message
        onSuccess.call(this)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] An error occurred while compiling Assembly\n')

        // then show notifications
        atom.notifications.addError('Errors while compiling Assembly', {detail: errors.join('')})

        // call error function
        onError.call(this)
      }
    })
  }

  /**
   * This function will fetch all C files (files ending with '.c') and build one
   * final binary from this sources.
   *
   * @return A promise resolving to sucess message or rejecting to an error message
   */
  onBuildCCode({buildAssembly, onSuccess, onError}) {
    // set fallback values
    buildAssembly = (typeof buildAssembly === 'undefined')  ? false     : buildAssembly
    onSuccess     = (typeof onSuccess === 'undefined')      ? () => {}  : onSuccess
    onError       = (typeof onError === 'undefined')        ? () => {}  : onError

    // skip if there is no active project!
    if ( !this.activeProject.projPath ) {
      this.viewMgr.showNoProjectNotification()
      return
    }

    // skip if there are no files to compile
    if (!this.activeProject.cFiles) {
      this.viewMgr.showNoCompilableCFilesNotification()
      return
    }

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    let command = 'docker'
    let clangCommand = 'clang '

    if (buildAssembly) {
      clangCommand += '-emit-llvm -S '
    }

    clangCommand += this.activeProject.cFiles.map((arg) => {
      return path.relative(this.activeProject.projPath, arg).replace(/\\/g, '/')
    }).join(' ')

    clangCommand += ' -o build/' + this.activeProject.binName

    if (buildAssembly) {
      clangCommand += '.bc'
    }

    const args = [
      'run',
      '--volume',
      this.activeProject.projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla && ' + clangCommand
    ]

    // create a new process
    this.runningProcess = childProcess.spawn(command, args)

    let errors = []
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.emitter.emit('add-c-error-text', data.toString())
      // increase counter
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // craft command
      command += ' ' + args.map((arg) => {
        return arg.charAt(0) != '-' ? '"' + arg + '"' : arg
      }).join(' ')

      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // react on output
      if (errors.length == 0) {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] Successfully compiled all C files from this project\n')

        // then show notifications
        atom.notifications.addSuccess('Successfully compiled C files')

        // we ware successful so run success callback
        onSuccess.call(this)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] An error occurred while compiling all C files from this project\n')

        // then show notifications
        atom.notifications.addError('Errors while compiling C files', {detail: errors.join('')})

        // run error callback
        onError.call(this)
      }
    })
  }

  onRunPatchedBinary({onSuccess, onError}) {
    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined')  ? () => {} : onSuccess
    onError   = (typeof onError === 'undefined')    ? () => {} : onError

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    // remove old trace file before new one would be created
    var traceFile = path.join(this.activeProject.outputDir, 'instrumented_' + this.activeProject.binName + '.trace')
    if ( fs.existsSync(traceFile) ) {
      fs.renameSync(traceFile, traceFile + '.' + (+new Date()))
    }

    let command = 'docker'
    const args = [
      'run',
      '--volume',
      this.activeProject.projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla/build && ./instrumented_' + this.activeProject.binName
    ]
    this.runningProcess = childProcess.spawn(command, args)

    // listen to streams
    let outputs = []
    this.runningProcess.stdout.on('data', (data) => {
      // log output
      this.emitter.emit('add-console-text', data.toString())
      // increase counter
      outputs.push(data.toString())
    })

    let errors = []
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.emitter.emit('add-c-error-text', data.toString())
      // increase counter
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // show exit of the program
      if (code != null) {
        this.emitter.emit('add-console-text', '\nProcess exited with code ' + code + '\n\n')
      } else if (signal != null) {
        this.emitter.emit('add-console-text', '\nProcess was killed due to signal ' + signal + '\n\n')
      }

      command += ' ' + args.map((arg) => {
        return arg.charAt(0) != '-' ? '"' + arg + '"' : arg
      }).join(' ')

      // first log command
      this.emitter.emit('add-log-text', '[CMD] ' + command + '\n')

      // react on output
      if (errors.length == 0) {
        // run callback
        onSuccess.call(this)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[MSG] An error occurred while running the patched binary\n')

        // then show notifications
        atom.notifications.addError('Errors while running the patched binary', {detail: errors.join('')})

        // run callback
        onError.call(this)
      }
    })
  }

  onRunBinary({onSuccess, onError}) {
    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess
    onError   = (typeof onError === 'unefined')    ? () => {} : onError

    // skip if there is no active project!
    if ( !this.activeProject.projPath ) {
      this.viewMgr.showNoProjectNotification()
      return
    }

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    const args = [
      'run',
      '--volume',
      this.activeProject.projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla/build && ./' + this.activeProject.binName
    ]
    this.runningProcess = childProcess.spawn('docker', args)

    // listen to streams
    let outputs = []
    this.runningProcess.stdout.on('data', (data) => {
      // log output
      this.emitter.emit('add-console-text', data.toString())
      // increase counter
      outputs.push(data.toString())
    })

    let errors = []
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.emitter.emit('add-c-error-text', data.toString())
      // increase counter
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // show exit of the program
      if (code != null) {
        this.emitter.emit('add-console-text', '\nProcess exited with code ' + code + '\n\n')
      } else if (signal != null) {
        this.emitter.emit('add-console-text', '\nProcess was killed due to signal ' + signal + '\n\n')
      }

      // react on output
      var binary = path.join(this.activeProject.outputDir, this.activeProject.binName)
      if (errors.length == 0) {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + binary + '\n')

        // call callback function
        onSuccess.call(this)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + binary + '\n[MSG] An error occurred while running the C binary from this project\n')

        // then show notifications
        atom.notifications.addError('Errors while running the C binary', {detail: errors.join('')})

        // call callback
        onError.call(this)
      }
    })
  }

  onRunTeSSLa({onSuccess, onError}) {
    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess
    onError   = (typeof onError === 'undefined')   ? () => {} : onError

    // skip if there is no active project!
    if ( !this.activeProject.projPath ) {
      this.viewMgr.showNoProjectNotification()
      return
    }

    // get json file
    var tsslJSON = path.join(this.activeProject.outputDir, 'instrumented_' + this.activeProject.binName + '.tessla.json')
    if ( !fs.existsSync(tsslJSON) ) {
      this.viewMgr.showNoTeSSLaJSONFoundNotification()
      return
    }

    // get the first found file
    var JSONString      = fs.readFileSync(tsslJSON).toString()
    var tsslJSONContent = JSON.parse(JSONString).items

    var outputArgs = []
    for (var id in tsslJSONContent) {
      var stream = tsslJSONContent[id]
      if (stream.out && stream.name) {
        outputArgs.push('-o')
        outputArgs.push(stream.id + ':' + stream.name)
      }
    }

    // disable other buttons
    this.viewMgr.disableButtons()
    this.viewMgr.enableStopButton()

    let command = 'docker'
    const args = [
      'run',
      '--volume',
      this.activeProject.projPath + ':/tessla',
      '--rm',
      'tessla',
      'sh',
      '-c',
      'cd /tessla && LANG=C.UTF-8 /tessla_server ' +
        path.relative(this.activeProject.projPath, tsslJSON).replace(/\\/g, '/') +
        ' --trace build/instrumented_' + this.activeProject.binName + '.trace ' +
        outputArgs.join(' ')
    ]

    // create a new process
    this.runningProcess = childProcess.spawn(command, args)

    // listen to streams
    let outputs = []
    this.runningProcess.stdout.on('data', (data) => {
      var dataString = data.toString()
      // log output
      this.emitter.emit('add-console-text', dataString)
      // store outputs in array
      outputs.push(dataString)
    })

    let errors = []
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.emitter.emit('add-tessla-error-text', data.toString())
      // increase counter
      errors.push(data.toString())
    })

    // on exit react
    this.runningProcess.on('close', (code, signal) => {// craft command
      command += ' ' + args.map((arg) => {
        return arg.charAt(0) != '-' ? '"' + arg + '"' : arg
      }).join(' ')

      // delete process reference
      this.runningProcess = null

      // unlock buttons
      this.viewMgr.enableButtons()
      this.viewMgr.disableStopButton()

      // show exit of the program
      if (code != null) {
        this.emitter.emit('add-console-text', '\nProcess exited with code ' + code + '\n\n')
      } else if (signal != null) {
        this.emitter.emit('add-console-text', '\nProcess was killed due to signal ' + signal + '\n\n')
      }

      // react on output
      if (errors.length == 0) {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n')

        // call callback function
        onSuccess.call(this, outputs)
      } else {
        // first log command
        this.emitter.emit('add-log-text', '[CMD] ' + command + '\n[MSG] An error occurred while running the TeSSLa server\n')

        // then show notifications
        atom.notifications.addError('Errors while running TeSSLa server', {detail: errors.join('')})

        // call callback
        onError.call(this)
      }
    })
  }

  onStopRunningActiveProcess() {
    // kill process and enable buttons
    if (this.runningProcess) {
      this.runningProcess.kill('SIGKILL')
    }
  }
}
