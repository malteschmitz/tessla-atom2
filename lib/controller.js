'use babel';

/* global atom */
import path from 'path';
import childProcess from 'child_process';
import fs from 'fs-extra';
import os from 'os';

import MessageView from './message-view';
import FileManager from './file-manager';
import { MESSAGE_TYPE } from './constants';

/**
 * Represents a controller object that handels user input and will manipulate
 * the view based on these inputs.
 * @author Malte Schmitz <malte.schmitz@isp.uni-luebeck.de>
 * @author Denis-Michael Lux <denis.lux@icloud.com>
 */
export default class Controller {
  // Config for the scan folder lib
  sfConfig: { dotfolder: false, dotfiles: false, modules: false };

  constructor(viewManager) {
    // view objects connected to this constructor
    this.viewManager = viewManager

    // get a reference for the currently running process
    this.runningProcess = null;
    this.containerDir = path.join(os.homedir(), '.tessla-env');
    this.containerBuild = path.join(this.containerDir, 'build');
  }

  /**
   * Creates a zlog file in the current project directory.
   * @return {void}
   */
  createZlogFile() {
    // craft content of zlog file
    const binName = this.viewManager.activeProject.binName;

    let formats = '[formats]\n';
    formats += `variable_values = "${atom.config.get('tessla.variableValueFormatting')}"\n`;
    formats += `function_calls = "${atom.config.get('tessla.functionCallFormatting')}"\n`;

    let rules = '[rules]\n';
    rules += `variable_values_cat.DEBUG "instrumented_${binName}.trace"; variable_values\n`;
    rules += `function_calls_cat.DEBUG "instrumented_${binName}.trace"; function_calls\n`;

    // first remove existing zlog
    if (fs.existsSync(path.join(this.containerDir, 'zlog.conf'))) {
      fs.unlinkSync(path.join(this.containerDir, 'zlog.conf'));
    }

    // then create new zlog.conf file
    fs.writeFileSync(path.join(this.containerDir, 'zlog.conf'), formats + rules);
  }

  /**
   * Compiles and runs the C code form the current project directory.
   * @return {void}
   */
  onCompileAndRunCCode() {
    // skip if there is no active project!
    if (!this.viewManager.activeProject.projPath) {
      this.viewManager.showNoProjectNotification();
      return;
    }

    // skip if there is already a running process!
    if (this.runningProcess !== null) {
      this.viewManager.showCurrentlyRunningProcessNotification();
      return;
    }

    // Save all other text editors
    this.viewManager.saveEditors();

    // Then compile C code
    this.onBuildCCode({ buildAssembly: false, onSuccess: () => this.onRunBinary({}) });
  }

  /**
   * Compiles and runs all C code and tessla specs from the current project directory.
   * @return {void}
   */
  onCompileAndRunProject() {
    // skip if there is no active project!
    if (this.viewManager.activeProject.projPath === '') {
      this.viewManager.showNoProjectNotification();
      return;
    }

    // console.log(this.viewManager.activeProject.projPath);
    // console.log(this.viewManager.activeProject.cFiles);

    // skip if there is already a running process!
    if (this.runningProcess !== null) {
      this.viewManager.showCurrentlyRunningProcessNotification();
      return;
    }

    // Save all other text editors
    this.viewManager.saveEditors();

    // start compilation process
    this.onBuildCCode({                               // First compile C code into Assembly
      onSuccess: () => this.onPatchAssembly({         // then patch Assembly
        onSuccess: () => this.onBuildAssembly({       // compile patched Assembly
          onSuccess: () => this.onRunPatchedBinary({  // run patched binary
            onSuccess: () => this.onBuildTeSSLa({     // build TeSSLa code
              onSuccess: () => this.onRunTeSSLa({
                onSuccess: (lines) => {
                  // emit signal that components can update with correct output values
                  this.viewManager.views.formattedOutputView.update(lines);
                },
              }),  // run TeSSLa server
              onError: this.viewManager.highlightTeSSLaError,
            }),
          }),
        }),
      }),
      buildAssembly: true,
    });
  }

  /**
   * Loads libInstrumentFunctions.so stuff into the C bytecode.
   * @param {object} config - A success and an error callback that will be
   * invoked after successful or faulty compilation
   * @return {void}
   */
  onPatchAssembly({ onSuccess, onError }) {
    // set fallback for functions that should be instrumented
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    // get vars for paths
    const binName = this.viewManager.activeProject.binName;

    // fetch all tessla files from project directory
    let args = [
      'exec', 'tessla', '/usr/lib/llvm-3.8/bin/opt', '-load', '/InstrumentFunctions/libInstrumentFunctions.so',
      '-instrument_function_calls', path.join('build', `${binName}.bc`),
    ];

    FileManager.collectCFunctionsFromSourceFile({
      sourceFile: this.viewManager.activeProject.tesslaFiles[0],
      projectPath: this.viewManager.activeProject.projPath,
    }).forEach((value) => { args = args.concat(['-instrument', value.functionName]); });

    // create command and args
    args = args.concat(['-o', `build/instrumented_${binName}.bc`]);

    // check if the tessla docker container is still running
    this.checkDockerContainer();

    // start process
    this.runningProcess = childProcess.spawn('docker', args);

    // craft command
    const command = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, command);

    // get errors
    const errors = [];
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.viewManager.views.errorsCView.addEntry(data.toString());

      // increase counter
      errors.push(data.toString());
    });

    // on exit react
    this.runningProcess.on('close', () => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // react on output
      if (errors.length === 0) {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'Successfully patched Assembly');

        // then show notifications
        atom.notifications.addSuccess('Successfully patched Assembly');

        // then resolve by passing back the command and a message
        onSuccess.call(this);
      } else {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'An error occurred while patching Assembly');

        // then show notifications
        atom.notifications.addError('Errors while patching Assembly', { detail: errors.join('') });

        // all error callback function
        onError.call(this);
      }
    });
  }

  /**
   * Builds TeSSLa specification file
   * @param {object} config - A success and an error callback that will be
   * invoked after successful or faulty compilation
   * @return {void}
   */
  onBuildTeSSLa({ onSuccess, onError }) {
    // define atom variables
    const notifications = atom.notifications;

    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // skip if there are no files to compile
    if (!this.viewManager.activeProject.tesslaFiles) {
      this.viewManager.showNoCompilableTeSSLaFilesNotification();
      return;
    } else if (this.viewManager.activeProject.tesslaFiles.length > 1) {
      this.viewManager.showTooMuchCompilableTeSSLaFilesNotification();
    }

    // get active project file
    const fileActiveProject = this.viewManager.activeProject.tesslaFiles[0];

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    // create command and args
    const args = [
      'exec', 'tessla', 'java', '-jar', '/tessla-imdea-snapshot.jar',
      path.relative(this.viewManager.activeProject.projPath, fileActiveProject).replace(/\\/g, '/'),
    ];

    // check if the tessla docker container is still running
    this.checkDockerContainer();

    // create a new process
    this.runningProcess = childProcess.spawn('docker', args);

    // craft command
    const command = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, command);

    const outputs = [];
    this.runningProcess.stdout.on('data', (data) => { outputs.push(data.toString()); });

    const errors = [];
    this.runningProcess.stderr.on('data', (data) => { errors.push(data.toString()); });

    // on exit react
    this.runningProcess.on('close', () => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // create strings from arrays
      let stdout = outputs.join();
      const stderr = errors.join();

      // check for compiler errors
      if (stdout.charAt(0) === '{') {
        // cut trailing comma
        //
        // Why the hell the compiler puts an trailing ',' to the string?? should
        // actually be fixed in the compiler binary not in this package!!!!
        if (stdout.charAt(stdout.length - 2) === ',') {
          stdout = `${stdout.slice(0, -2)}\n`;
        }

        // here we know the compilation process was successful so write content to file
        fs.writeFileSync(path.join(this.containerBuild, `instrumented_${this.viewManager.activeProject.binName}.tessla.json`), stdout);

        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, `Successfully compiled ${path.relative(this.viewManager.activeProject.projPath, fileActiveProject).replace(/\\/g, '/')}`);

        // then show notifications
        notifications.addSuccess('Successfully compiled TeSSLa file');

        // remove markers from TeSSLa source code
        this.viewManager.removeTeSSLaSourceMarkers();

        // then resolve by passing back the command and a message
        onSuccess.call(this);
      } else {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, `An error occurred while compiling ${fileActiveProject}`);
        this.viewManager.views.errorsTeSSLaViews.addEntry(stderr + stdout);

        // then show notifications
        notifications.addError('Errors while compiling TeSSLa file', { detail: stderr + stdout });

        // run error callback
        onError.call(this, { error: stderr + stdout, file: fileActiveProject });
      }
    });
  }

  /**
   * Builds modified assembly
   * @param {object} config - A success and an error callback that will be
   * invoked after successful or faulty compilation
   * @return {void}
   */
  onBuildAssembly({ onSuccess, onError }) {
    // atom variables
    const notifications = atom.notifications;

    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    const args = [
      'exec', 'tessla', 'clang++', path.join('build', `instrumented_${this.viewManager.activeProject.binName}.bc`),
      '-o', `build/instrumented_${this.viewManager.activeProject.binName}`, '-lzlog', '-lpthread',
      '-L/usr/local/lib', '-L/InstrumentFunctions', '-lLogger',
    ];

    // check if the tessla docker container is still running
    this.checkDockerContainer();

    // create a new process
    this.runningProcess = childProcess.spawn('docker', args);

    // craft command
    const command = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, command);

    const errors = [];
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.viewManager.views.errorsCView.addEntry(data.toString());
      // increase counter
      errors.push(data.toString());
    });

    // on exit react
    this.runningProcess.on('close', () => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // react on output
      if (errors.length === 0) {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'Successfully compiled Assembly');

        // then show notifications
        notifications.addSuccess('Successfully compiled Assembly');

        // then resolve by passing back the command and a message
        onSuccess.call(this);
      } else {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'An error occurred while compiling Assembly');

        // then show notifications
        notifications.addError('Errors while compiling Assembly', { detail: errors.join('') });

        // call error function
        onError.call(this);
      }
    });
  }

  /**
   * This function will fetch all C files (files ending with '.c') and build one
   * final binary from this sources.
   * @param {Object} config - An object containing information about the compilation process.
   * @return {void}
   */
  onBuildCCode({ buildAssembly, onSuccess, onError }) {
    // define atom variables
    const notifications = atom.notifications;

    // set fallback values
    buildAssembly = (typeof buildAssembly === 'undefined') ? false : buildAssembly;
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // skip if there is no active project!
    if (this.viewManager.activeProject.projPath === '') {
      this.viewManager.showNoProjectNotification();
      return;
    }
    // console.log(this.viewManager.activeProject.projPath);
    // console.log(this.viewManager.activeProject.cFiles);

    // skip if there are no files to compile
    if (!this.viewManager.activeProject.cFiles) {
      this.viewManager.showNoCompilableCFilesNotification();
      return;
    }

    // skip if there is already a running process!
    if (this.runningProcess !== null) {
      this.viewManager.showCurrentlyRunningProcessNotification();
      return;
    }

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    // transfer stuff to container
    this.transferFilesToContainer();

    // get docker command args
    const outFile = path.join('build', this.viewManager.activeProject.binName + (buildAssembly ? '.bc' : ''));

    let args = ['exec', 'tessla', 'clang', '-o', outFile];

    if (buildAssembly) {
      args = args.concat(['-emit-llvm', '-S']);
    }

    // put c files into args array
    args = args.concat(this.viewManager.activeProject.cFiles.map((arg) => {
      return path.relative(this.viewManager.activeProject.projPath, arg).replace(/\\/g, '/');
    }));

    // check if the docker tessla container is still up running
    this.checkDockerContainer();

    // create a new process
    this.runningProcess = childProcess.spawn('docker', args);

    // craft command
    const command = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, command);

    const errors = [];
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.viewManager.views.errorsCView.addEntry(data.toString());
      // increase counter
      errors.push(data.toString());
    });

    // on exit react
    this.runningProcess.on('close', () => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // react on output
      if (errors.length === 0) {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'Successfully compiled C files');

        // then show notifications
        notifications.addSuccess('Successfully compiled C files');

        // we ware successful so run success callback
        onSuccess.call(this);
      } else {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'An error occurred while compiling C files');

        // then show notifications
        notifications.addError('Errors while compiling C files', { detail: errors.join('') });

        // run error callback
        onError.call(this);
      }
    });
  }

  /**
   * Runs the patched binary.
   * @param {object} config - A success and an error callback that will be
   * invoked after successful or faulty compilation
   * @return {void}
   */
  onRunPatchedBinary({ onSuccess, onError }) {
    // define atom variables
    const notifications = atom.notifications;

    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    // remove old trace file before new one would be created
    const traceFile = path.join(this.containerDir, `instrumented_${this.viewManager.activeProject.binName}.trace`);
    if (fs.existsSync(traceFile)) {
      fs.renameSync(traceFile, `${traceFile}.${+new Date()}`);
    }

    // get docker args
    const args = ['exec', 'tessla', `./build/instrumented_${this.viewManager.activeProject.binName}`];

    // check if the tessla docker container is still running
    this.checkDockerContainer();

    // start process
    this.runningProcess = childProcess.spawn('docker', args);

    // craft command
    const command = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, command);

    // listen to streams
    const outputs = [];
    this.runningProcess.stdout.on('data', (data) => {
      // log output
      this.viewManager.views.consoleView.addEntry(data.toString());
      // increase counter
      outputs.push(data.toString());
    });

    const errors = [];
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.viewManager.views.errorsCView.addEntry(data.toString());
      // increase counter
      errors.push(data.toString());
    });

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // show exit of the program
      if (code != null) {
        this.viewManager.views.consoleView.addEntry(`Process exited with code ${code}`);
      } else if (signal != null) {
        this.viewManager.views.consoleView.addEntry(`Process was killed due to signal ${signal}`);
      }

      // react on output
      if (errors.length === 0) {
        // run callback
        onSuccess.call(this);
      } else {
        // first log command
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'An error occurred while running the patched binary');

        // then show notifications
        notifications.addError('Errors while running the patched binary', { detail: errors.join('') });

        // run callback
        onError.call(this);
      }
    });
  }

  /**
   * Runs the fully compiled binary containing all library functions
   * @param {object} config - A success and an error callback that will be
   * invoked after successful or faulty compilation
   * @return {void}
   */
  onRunBinary({ onSuccess, onError }) {
    // define atom variables
    const notifications = atom.notifications;

    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // skip if there is no active project!
    if (!this.viewManager.activeProject.projPath) {
      this.viewManager.showNoProjectNotification();
      return;
    }

    // skip if there is already a running process!
    if (this.runningProcess !== null) {
      this.viewManager.showCurrentlyRunningProcessNotification();
      return;
    }

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    // get args for the docker command
    const args = ['exec', 'tessla', `./build/${this.viewManager.activeProject.binName}`];

    // check if the tessla docker container is still running
    this.checkDockerContainer();

    // start process
    this.runningProcess = childProcess.spawn('docker', args);

    // craft command
    const binary = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, binary);

    // listen to streams
    const outputs = [];
    this.runningProcess.stdout.on('data', (data) => {
      // log output
      this.viewManager.views.consoleView.addEntry(data.toString());
      // increase counter
      outputs.push(data.toString());
    });

    const errors = [];
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.viewManager.views.errorsCView.addEntry(data.toString());
      // increase counter
      errors.push(data.toString());
    });

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // show exit of the program
      if (code != null) {
        this.viewManager.views.consoleView.addEntry(`Process exited with code ${code}`);
      } else if (signal != null) {
        this.viewManager.views.consoleView.addEntry(`Process was killed due to signal ${signal}`);
      }

      // react on output
      if (errors.length === 0) {
        // call callback function
        onSuccess.call(this);
      } else {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'An error occurred while running C binary');

        // then show notifications
        notifications.addError('Errors while running the C binary', { detail: errors.join('') });

        // call callback
        onError.call(this);
      }
    });
  }

  /**
   * Runs a tessla specification file
   * @param {object} config - A success and an error callback that will be
   * invoked after successful or faulty compilation
   * @return {void}
   */
  onRunTeSSLa({ onSuccess, onError }) {
    // define atom variables
    const notifications = atom.notifications;

    // set fallback values
    onSuccess = (typeof onSuccess === 'undefined') ? () => {} : onSuccess;
    onError = (typeof onError === 'undefined') ? () => {} : onError;

    // skip if there is no active project!
    if (!this.viewManager.activeProject.projPath) {
      this.viewManager.showNoProjectNotification();
      return;
    }

    // get json file
    const tsslJSON = path.join(this.containerBuild, `instrumented_${this.viewManager.activeProject.binName}.tessla.json`);
    if (!fs.existsSync(tsslJSON)) {
      this.viewManager.showNoTeSSLaJSONFoundNotification();
      return;
    }

    // get the first found file
    const JSONString = fs.readFileSync(tsslJSON).toString();
    const tsslJSONContent = JSON.parse(JSONString).items;

    const outputArgs = [
      'LANG=C.UTF-8', '/tessla_server', path.relative(this.containerDir, tsslJSON).replace(/\\/g, '/'),
      '--trace', `instrumented_${this.viewManager.activeProject.binName}.trace`,
    ];

    Object.keys(tsslJSONContent).forEach((key) => {
      const stream = tsslJSONContent[key];
      if (stream.out && stream.name) {
        outputArgs.push('-o');
        outputArgs.push(`${stream.id}:${stream.name}`);
      }
    });

    // disable other buttons
    this.viewManager.disableButtons();
    this.viewManager.enableStopButton();

    // get args for the docker command
    const args = ['exec', 'tessla', 'sh', '-c', `'${outputArgs.join(' ')}'`];

    // check if the tessla docker container is still running
    this.checkDockerContainer();

    // create a new process
    this.runningProcess = childProcess.spawn('docker', args, { shell: true });

    // craft command
    const command = `docker ${args.join(' ')}`;
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, command);

    // listen to streams
    const outputs = [];
    this.runningProcess.stdout.on('data', (data) => {
      // log output
      this.viewManager.views.consoleView.addEntry(data.toString());
      // store outputs in array
      outputs.push(data.toString());
    });

    const errors = [];
    this.runningProcess.stderr.on('data', (data) => {
      // log output
      this.viewManager.views.errorsTeSSLaViews.addEntry(data.toString());
      // increase counter
      errors.push(data.toString());
    });

    // on exit react
    this.runningProcess.on('close', (code, signal) => {
      // delete process reference
      this.runningProcess = null;

      // unlock buttons
      this.viewManager.enableButtons();
      this.viewManager.disableStopButton();

      // show exit of the program
      if (code != null) {
        this.viewManager.views.consoleView.addEntry(`Process exited with code ${code}`);
      } else if (signal != null) {
        this.viewManager.views.consoleView.addEntry(`Process was killed due to signal ${signal}`);
      }

      // react on output
      if (errors.length === 0) {
        // call callback function
        onSuccess.call(this, outputs);
      } else {
        // first log message
        this.viewManager.views.logView.addEntry(MESSAGE_TYPE.MSG, 'An error occurred while running the TeSSLa server');

        // then show notifications
        notifications.addError('Errors while running TeSSLa server', { detail: errors.join('') });

        // call callback
        onError.call(this);
      }
    });
  }

  /**
   * Stops the currently running process
   * @return {void}
   */
  onStopRunningProcess() {
    // kill process and enable buttons
    if (this.runningProcess) {
      // log kill command
      this.runningProcess.kill('SIGKILL');
      this.viewManager.views.logView.addEntry(MESSAGE_TYPE.CMD, `kill -9 ${this.runningProcess.pid}`);
    }
  }

  /**
   * Checks if the docker container is still up running.
   * @return {void}
   */
  checkDockerContainer() {
    // check if the tessla container ist still up running
    const id = childProcess.execSync('docker ps -q -f name=tessla').toString();

    console.log(id);

    // if there returned an id the container is still running
    if (id.length === 0) {
      // get args for the docker command
      const args = [
        'run', '--volume', `${this.containerDir}:/tessla`, '-w', '/tessla', '-tid',
        '--name', 'tessla', 'tessla', 'sh',
      ];

      // now restart docker container
      childProcess.spawnSync('docker', args);

      // emit signal to log command
      // log docker startup command in log stream
      this.viewManager.views.logView.addEntry(MESSAGE_TYPE.DKR, `docker ${args.join(' ')}`);
    }
  }

  /**
   * Copies files to the tessla-environment directory in the home directory
   * @return {void}
   */
  transferFilesToContainer() {
    // we have to move the containers to the containerDir
    // additionally there should be applied a filter to not move flag files etc
    fs.emptyDirSync(this.containerDir);
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.CMD, `rm -rf ${this.containerDir}/*`);

    // create build directory
    fs.mkdirSync(path.join(this.containerDir, 'build'));
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.CMD, `mkdir ${this.containerBuild}`);

    // create zlog file
    this.createZlogFile();

    // the copy stuff
    this.viewManager.views.logView.addEntry(MESSAGE_TYPE.CMD, `rsync -r --exclude=build,.gcc-flags.json ${this.viewManager.activeProject.projPath}/* ${this.containerDir}/`);
    fs.copy(this.viewManager.activeProject.projPath, this.containerDir, { filter: (src) => {
      // do not copy gcc flags
      if (path.posix.basename(src) === '.gcc-flags.json') {
        return false;
      }

      // do not copy build directory
      if (path.posix.basename(src) === 'build') {
        return false;
      }

      // in all other cases just copy
      return true;
    } }, (err) => {
      if (err) {
        console.error(err);
      }
    });
  }
}
