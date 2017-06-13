'use babel';

import { CompositeDisposable, Disposable } from 'atom';
import * as dependencies from 'atom-package-deps';
import path from 'path';
import os from 'os';
import fs from 'fs';
import childProcess from 'child_process';

import MessageView from './message-view';
import LogView from './log-view';
import SidebarView from './sidebar-view';
import OutputView from './output-view'
import Controller from './controller';
import ViewManager from './view-manager';
import Downloader from './downloader';
import { CONSOLE_VIEW, ERRORS_C_VIEW, ERRORS_TESSLA_VIEW, WARNINGS_VIEW, LOG_VIEW, SIDEBAR_VIEW, OUTPUT_VIEW, FORMATTED_OUTPUT_VIEW, MESSAGE_TYPE } from './constants';

export default {
  // config object
  config: {
    variableValueFormatting: {
      type: 'string',
      default: 'variable_values:%m %d(%s) %us%n',
      order: 1,
      title: 'zlog string format for variables',
      description: 'This setting will format the output of variables in the trace file',
    },
    functionCallFormatting: {
      type: 'string',
      default: 'function_calls:%m nil %d(%s) %us%n',
      order: 2,
      title: 'zlog string format for function calls',
      description: 'This setting will format the output of function calls in the trace file.',
    },
    animationSpeed: {
      type: 'integer',
      default: 200,
      order: 3,
      title: 'Animation speed',
      description: 'This will set the speed of animations used in this package. The time is represented in milliseconds.',
    },
    alreadySetUpDockerContainer: {
      type: 'boolean',
      default: false,
      order: 4,
      title: 'Docker already set up?',
      description: 'This flag is set to true if the docker container is already set up otherwise it will be set to false.'
    }
  },

  // ivars
  toggled: false,
  subscriptions: null,
  controller: null,
  viewManager: null,
  activeProject: null,
  toolBarButtons: {},
  messageQueue: [],
  containerDir: path.join(os.homedir(), '.tessla-env'),
  imageDir: path.join(path.dirname(__dirname), 'docker-image'),

  // activates the package
  activate() {

    // start download process if this package is activated first
    if (!atom.config.get('tessla.alreadySetUpDockerContainer')) {
      // download tessla image
      Downloader.download({
        url: 'http://rv.isp.uni-luebeck.de/tessla/tessla-docker.zip',
        filePath: path.join(this.imageDir, 'tessla-docker.zip'),
        callback: () => {},
      });
    }

    // install package dependencies
    dependencies.install('tessla').catch(error => {
      console.err(error);

      notifications.addError('Could not start TeSSLa package', {
        detail: `Package dependencies could not be installed. The package was not started because the TeSSLa package will not run properly without this dependencies.\n${error.message}`,
      });

      return;
    });

    // set up container directory
    fs.stat(this.containerDir, (err, stats) => {
      if(err && err.code === 'ENOENT') {
        fs.mkdir(this.containerDir, () => {
          // create container directory
          this.messageQueue.push({type: MESSAGE_TYPE.CMD, msg: `mkdir ${this.containerDir}`});

          // create build directory in container directory
          fs.mkdir(path.join(this.containerDir, 'build'), () => {
            this.messageQueue.push({type: MESSAGE_TYPE.CMD, msg: `mkdir ${path.join(this.containerDir, 'build')}`});

            // start docker tessla container
            const dockerArgs = ['run', '--volume', `${this.containerDir}:/tessla`, '-w', '/tessla', '-tid', '--name', 'tessla', 'tessla', 'sh'];
            childProcess.spawn('docker', dockerArgs);

            // log command
            this.messageQueue.push({type: MESSAGE_TYPE.DKR, msg: `docker ${dockerArgs.join(' ')}`});
          });
        });
      } else {
        // if file exists just start docker
        // start docker tessla container
        const dockerArgs = ['run', '--volume', `${this.containerDir}:/tessla`, '-w', '/tessla', '-tid', '--name', 'tessla', 'tessla', 'sh'];
        childProcess.spawn('docker', dockerArgs);

        // log command
        this.messageQueue.push({type: MESSAGE_TYPE.DKR, msg: `docker ${dockerArgs.join(' ')}`});
      }
    });

    // create view manager
    this.viewManager = new ViewManager(this.activeProject);

    // create the controller object
    this.controller = new Controller(this.viewManager);

    // Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    this.subscriptions = new CompositeDisposable(
      atom.commands.add('atom-workspace', {
        'tessla:toggle': () => this.toggle(),
        'tessla:set-up-split-view': () => this.viewManager.setUpSplitView(),
        'tessla:build-and-run-c-code': () => this.controller.onCompileAndRunCCode(),
        'tessla:build-c-code': () => this.controller.onBuildCCode({buildAssembly: false, onSuccess: () => {}, onError: () => {}}),
        'tessla:run-c-code': () => this.controller.onRunBinary({onSuccess: () => {}, onError: () => {}}),
        'tessla:stop-current-process': () => this.controller.onStopRunningProcess(),
        'tessla:build-and-run-project': () => this.controller.onCompileAndRunProject(),
        'tessla:reset-view': () => this.viewManager.restoreViews()
      }),

      // openers for custom views
      atom.workspace.addOpener(URI => {
        // openers for custom view elements
        if (URI === CONSOLE_VIEW) {
          return new MessageView({ title: 'Console', URI: CONSOLE_VIEW });
        }

        if (URI === ERRORS_C_VIEW) {
          return new MessageView({ title: 'Errors (C)', URI: ERRORS_C_VIEW });
        }

        if (URI === ERRORS_TESSLA_VIEW) {
          return new MessageView({ title: 'Errors (TeSSLa)', URI: ERRORS_TESSLA_VIEW });
        }

        if (URI === WARNINGS_VIEW) {
          return new MessageView({ title: 'Warnings', URI: WARNINGS_VIEW});
        }

        if (URI === LOG_VIEW) {
          return new LogView({ title: 'Log', URI: LOG_VIEW });
        }

        if (URI === SIDEBAR_VIEW) {
          return new SidebarView({ title: 'Functions', URI: SIDEBAR_VIEW });
        }

        if (URI === FORMATTED_OUTPUT_VIEW) {
          return new OutputView({ title: 'Formatted output', URI: FORMATTED_OUTPUT_VIEW });
        }
      }),

      // add an disposal which will destroy all view components
      new Disposable(() => {
        atom.workspace.getPaneItems().forEach(item => {
          if (item instanceof MessageView || item instanceof LogView || item instanceof SidebarView || item instanceof OutputView) {
            item.destroy();
          }
        });
      })
    );
  },

  // deactivates the package and handles all stuff that happens then
  deactivate() {
    // dispose subscriptions
    this.subscriptions.dispose();
    // stop docker container
    childProcess.spawnSync('docker', ['rm', '-f', 'tessla']);
  },

  // toggles the package
  toggle() {
    // get active editor from view
    let activeEditor;

    atom.workspace.getTextEditors().forEach(editor => {
      // console.log(editor, atom.views.getView(editor).offsetParent === null);
      // if the editor is visible remember it
      if (atom.views.getView(editor).offsetParent !== null) {
        activeEditor = editor;
      }
    });

    //console.log(activeEditor, atom.views.getView(activeEditor));
    // set project path to the active file path
    if (activeEditor) {
      this.viewManager.activeProject.setProjPath(path.dirname(activeEditor.getPath()));
    }

    // collect all promises for the view setup process
    const viewSetup = [
      atom.workspace.toggle(CONSOLE_VIEW),
      atom.workspace.toggle(ERRORS_C_VIEW),
      atom.workspace.toggle(ERRORS_TESSLA_VIEW),
      atom.workspace.toggle(WARNINGS_VIEW),
      atom.workspace.toggle(LOG_VIEW),
      atom.workspace.toggle(FORMATTED_OUTPUT_VIEW),
      atom.workspace.toggle(SIDEBAR_VIEW),
    ];

    // if all promises resolved do something
    Promise.all(viewSetup).then(views => {
      const viewsContainer = {};

      // figure out which object belongs to which class
      views.forEach(view => {
        if (view) {
          switch (view.getURI()) {
            case CONSOLE_VIEW: viewsContainer.consoleView = view; break;
            case ERRORS_C_VIEW: viewsContainer.errorsCView = view; break;
            case ERRORS_TESSLA_VIEW: viewsContainer.errorsTeSSLaViews = view; break;
            case WARNINGS_VIEW: viewsContainer.warningsView = view; break;
            case LOG_VIEW: viewsContainer.logView = view; break;
            case SIDEBAR_VIEW: viewsContainer.sidebarViews = view; break;
            case FORMATTED_OUTPUT_VIEW: viewsContainer.formattedOutputView = view; break;
            default: viewsContainer.unknown = view; break;
          }
        }
      });

      // connect views to the controller
      this.viewManager.connectViews(viewsContainer);

      // connect icons to the message view/log view tabss
      this.viewManager.addIconsToTabs();

      // set up split view
      this.viewManager.setUpSplitView();

      // log setup commands to log view that were executed during activation
      // process.
      this.messageQueue.forEach(element => {
        viewsContainer.logView.addEntry(element.type, element.msg);
      });

      this.messageQueue = [];
    });
  },

  consumeToolBar(getToolBar) {
    toolBar = getToolBar('tessla');

    // adding the c-compile button
    this.toolBarButtons.BuildAndRunCCode = toolBar.addButton({
      icon: 'play-circle',
      callback: 'tessla:build-and-run-c-code',
      tooltip: 'Builds and runs C code from project directory',
      iconset: 'fa',
    });

    // adding the build button
    this.toolBarButtons.BuildCCode = toolBar.addButton({
      icon: 'gear-a',
      callback: 'tessla:build-c-code',
      tooltip: 'Builds the C code of this project into a binary',
      iconset: 'ion',
    });

    this.toolBarButtons.RunCCode = toolBar.addButton({
      icon: 'play',
      callback: 'tessla:run-c-code',
      tooltip: 'Runs the binaray compiled from C code',
      iconset: 'ion',
    });

    toolBar.addSpacer();

    // adding the complete code run button
    this.toolBarButtons.BuildAndRunProject = toolBar.addButton({
      // icon:     'bar-chart',
      icon: 'ios-circle-filled',
      callback: 'tessla:build-and-run-project',
      tooltip: 'Builds and runs C code and analizes runtime behavior',
      // iconset:  'fa'
      iconset: 'ion',
    });

    // adding a seperator
    toolBar.addSpacer();

    // adding the stop button and disable it immediatly
    this.toolBarButtons.Stop = toolBar.addButton({
      icon: 'android-checkbox-blank',
      callback: 'tessla:stop-current-process',
      tooltip: 'Stops the process that is currently running',
      iconset: 'ion',
    });
    this.toolBarButtons.Stop.setEnabled(false);

    // adding a seperator
    toolBar.addSpacer();

    toolBar.addButton({
      icon: 'columns',
      callback: 'tessla:set-up-split-view',
      tooltip: 'Set up split view',
      iconset: 'fa',
    });

    this.toolBarButtons.showLog = toolBar.addButton({
      icon: 'window-maximize',
      callback: 'tessla:reset-view',
      tooltip: 'Restore all view Components',
      iconset: 'fa',
    });

    // connect buttons to the view manager
    this.viewManager.connectBtns(this.toolBarButtons);

    // change the tool-bar size
    atom.config.set('tool-bar.iconSize', '16px');
    atom.config.set('tool-bar.position', 'Right');
  }
};
