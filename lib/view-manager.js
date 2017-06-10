'use babel';

import { MESSAGE_TYPE, CONSOLE_VIEW, ERRORS_C_VIEW, ERRORS_TESSLA_VIEW, WARNINGS_VIEW, LOG_VIEW, SIDEBAR_VIEW, OUTPUT_VIEW, FORMATTED_OUTPUT_VIEW } from './constants';
import Project from './project';

export default class ViewManager {

  constructor(activeProject) {
    // set initial value for the view object
    this.views = {};
    this.toolBarButtons = {};

    // an array of markers added to the text editor
    this.tesslaMarkers = [];
    this.tesslaUnsedFunctionMarkers = [];
    this.tesslaTooltipDecorations = [];

    // set active project
    this.activeProject = new Project();

    // bind this reference to the on destroyed view method
    this.onDestroyedView = this.onDestroyedView.bind(this);
    atom.workspace.onDidDestroyPaneItem(this.onDestroyedView);

    // keep track for workspace changes
    atom.workspace.onDidStopChangingActivePaneItem((item) => {
      // emit change event
      if (atom.workspace.isTextEditor(item)) {
        this.onFileChanged(item.getPath());
      } else {
        this.onNoOpenFile();
      }
    });

    // if a file will be added to the workspace
    atom.workspace.onDidAddTextEditor((event) => {
      this.onFileSavedOrAdded(event.textEditor.getPath());
    });

    // listen for changes in the text editors
    atom.workspace.observeTextEditors((editor) => {
      editor.onDidSave((event) => {
        this.onFileSavedOrAdded(event.path);
      });

      editor.onDidStopChanging((event) => {
        // console.log("stopped changing editing text editors."),
        if (typeof this.views.sidebarViews !== 'undefined') {
          this.views.sidebarViews.update(this.activeProject);
        }
      });
    });
  }

  connectBtns(btns) {
    this.toolBarButtons = btns;
  }

  connectViews(views) {
    this.views = views;

    // connect this view manager to the sidebar
    this.views.sidebarViews.setViewManager(this);
  }

  onDestroyedView(view) {
    if (view.item) {
      switch (view.item.getURI()) {
        case CONSOLE_VIEW: this.views.consoleView = null; break;
        case ERRORS_C_VIEW: this.views.errorsCView = null; break;
        case ERRORS_TESSLA_VIEW: this.views.errorsTeSSLaViews = null; break;
        case WARNINGS_VIEW: this.views.warningsView = null; break;
        case LOG_VIEW: this.views.logView = null; break;
        case SIDEBAR_VIEW: this.views.sidebarViews = null; break;
        case FORMATTED_OUTPUT_VIEW: this.views.formattedOutputView = null; break;
        default: this.views.unknown = null; break;
      }
    }
  }

  /**
   * Splits the workspace into two different view. The left view will contain
   * all C files and the right view will contain the tessla specification files.
   * @return {void}
   */
  setUpSplitView() {
    // if there are no files then the split view can not be set up
    if (!this.activeProject.cFiles && !this.activeProject.tesslaFiles) {
      this.showNotSetUpSplitViewNotification();
      return;
    }

    // first get panes and destroy them
    atom.workspace.getTextEditors().forEach((editor) => {
      // editor.save();
      editor.destroy();
    });

    // create two panes
    atom.workspace.getPanes()[0].splitRight();

    // add files to pane
    this.activeProject.cFiles.forEach((file) => { atom.workspace.open(file, { split: 'left' }); });

    this.activeProject.tesslaFiles.forEach((file) => {
      atom.workspace.open(file, { split: 'right' }).then((editor) => {
        // add a gutter to each tessla file
        editor.addGutter({ name: 'tessla-error-gutter', priority: 1000, visible: true });
      });
    });
  }

  /**
   * Sets the active object properties if file has changed. This method gets invoked
   * each time a file in the workspace is saved or a new file is added to the workspace.
   * @param {string} file - The file path that was added or saved
   * @return {void}
   */
  onFileSavedOrAdded(file) {
    // console.log('TeSSLaController.onFileSavedOrAdded(' + file + ')')
    // get new Project path
    const newProjectPath = atom.project.relativizePath(file)[0];

    // if the new Project path is different from the current then emit signal
    // to force subscribers to update thier path
    if (this.activeProject.projPath !== newProjectPath) {
      // set new path values
      this.activeProject.setProjPath(newProjectPath);

      // setup project structure
      this.activeProject.setUpProjectStructure();
    } else {
      if (typeof this.views.sidebarViews !== 'undefined') {
        this.views.sidebarViews.update(this.activeProject);
      }
    }
  }

  /**
   * Sets the active project properties to the file that is now active in the workspace.
   * @param {string} file - The file that is now active in the workspace
   * @return {void}
   */
  onFileChanged(file) {
    // console.log('TeSSLaController.onFileChanged(' + file + ')')
    if (typeof file === 'undefined') {
      return;
    }

    // get new Project path
    const newProjectPath = atom.project.relativizePath(file)[0];

    // if the new Project path is different from the current then emit signal
    // to force subscribers to update thier path
    if (this.activeProject.projPath !== newProjectPath) {
      // set own value
      this.activeProject.setProjPath(newProjectPath);

      // this.setUpProjectStructure()
      this.activeProject.setUpProjectStructure();

      // update function sidebar
      if (typeof this.views.sidebarViews !== 'undefined') {
        this.views.sidebarViews.update(this.activeProject);
      }
    }
  }

  /**
   * Clears the active project object since there is no open file in the workspace.
   * @return {void}
   */
  onNoOpenFile() {
    // console.log('TeSSLaController.onNoOpenFile()');
    // if (this.activeProject.projPath !== '') {
    //   // set path to empty values
    //   this.activeProject.clear();
    // }
  }

  /**
   * Shows a notification that there is no active project in workspace
   * @return {void}
   */
  showNoProjectNotification() {
    // show notification to user
    const message = 'There is no active project in your workspace. Open and activate at least one file of the project you want to compile and run in your workspace.';

    // show notification
    atom.notifications.addError('Unable to compile and run C code', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.views.consoleView.addEntry(message);
  }

  /**
   * Shows a notification that there are no compileable C files in the project directory
   * @return {void}
   */
  showNoCompilableCFilesNotification() {
    // show notification to user
    const message = 'There are no C files to compile in this project. Create at least one C file in this project containing a main function to build a runable binary.';

    // show notification
    atom.notifications.addError('Unable to compile C files', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.views.errorsCView.addEntry(message);
  }

  /**
   * Shows a notification that indicates that there is no executable binary in this project
   * @return {void}
   */
  showNoCBinaryToExecuteNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There is no C binary in the build directory which can be executed. You first have to build your C code to generate a binary.';

    // show notification
    atom.notifications.addError('Unable to run binary', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.views.errorsCView.addEntry(message);
  }

  /**
   * Shows a notification that indicates that the split view could not be set up
   * @return {void}
   */
  showNotSetUpSplitViewNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There are no ".tessla" and ".c" files to put into split view in the current project. Please open at least one file of your project and activate it in workspace to properly set up the split view. The split view can be set up by right click onto your source file in the text editor and select "Set up TeSSLa split view" in the context menu.';

    // show notification
    atom.notifications.addWarning('Could not set up the split view', {
      detail: message,
    });

    // emit an event for inserting text into console
    //this.views.warningsView.addEntry(message);
  }

  /**
   * Shows a notification that there was no TeSSLa JSON found in the project
   * @return {void}
   */
  showNoTeSSLaJSONFoundNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'No TeSSLa JSON file found!';

    // show notification
    atom.notifications.addError('Unable to find TeSSLa JSON file', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.views.consoleView.addEntry(message);
  }

  /**
   * Shows a notification that the split view could not be set up due to missing project
   * @return {void}
   */
  showNoActiveProjectForSplitViewNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'No Project currently active. To set up the split view at least one file should be active for setting up the split view';

    // show notification
    atom.notifications.addWarning('Could not set up the split view', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.views.warningsView.addEntry(message);
  }

  /**
   * Shows a notification that indicates that there is currently a process running
   * @return {void}
   */
  showCurrentlyRunningProcessNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There is a process that is currently running. A new action can only be performed if there is no action currently running.';

    // show notification
    atom.notifications.addWarning('Unable to perform action', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.views.consoleView.addEntry(message);
  }

  /**
   * Highlights unused functions in the text editor. By bounding the function definition into a
   * rounded rectangle
   * @param {Object} config - An object containing a list of unused functions a the related tessla
   * file
   * @return {void}
   */
  onHighlightUnusedFunctions({ unusedFunctions, tesslaFile }) {
    // define Atom variables
    const workspace = atom.workspace;

    // console.log('TeSSLaController.onHighlightUnusedFunctions()', unusedFunctions)

    // get editor that contains the tessla file
    const editors = workspace.getTextEditors();
    let editorFile = null;

    editors.forEach((editor) => {
      if (editor.getPath() === tesslaFile) {
        editorFile = editor;
      }
    });

    // if the editor exists
    if (editorFile) {
      // remove current markers
      this.tesslaUnsedFunctionMarkers.forEach((marker) => {
        marker.destroy();
      });
      this.tesslaUnsedFunctionMarkers = [];

      // get editor content
      const text = editorFile.getText();

      // create line counter variable
      let lineCounter = 0;

      // read content line by line
      text.split('\n').forEach((line) => {
        // look for function_calls
        unusedFunctions.forEach((func) => {
          const lookupText = `function_calls("${func}")`;
          const idx = line.indexOf(lookupText);

          // if there were a match
          if (idx !== -1) {
            // create range
            const range = new Range(
              new Point(lineCounter, idx),
              new Point(lineCounter, idx + lookupText.length),
            );

            // create marker
            const marker = editorFile.markBufferRange(range);
            this.tesslaUnsedFunctionMarkers.push(marker);

            // decorate marker
            editorFile.decorateMarker(marker, {
              type: 'highlight',
              class: 'tessla-unused-function',
            });
          }
        });

        lineCounter += 1;
      });
    }
  }

  /**
   * Highlights errors in the tessla source code.
   * @param {Object} config - An object containing the error string and the a file path
   * @return {void}
   */
  highlightTeSSLaError({ error, file }) {
    // Atom workspace
    const workspace = atom.workspace;

    // first parse error
    const regex = /\b(ParserError)\(\(([\s,0-9-]+)\):\s(.*)\)/g;

    // get matches
    const match = regex.exec(error);

    // if there were matches then highlight
    if (match) {
      // remove old markers
      this.tesslaMarkers.forEach((marker) => { marker.destroy(); });
      this.tesslaMarkers = [];
      this.tesslaTooltipDecorations = [];

      // extract information
      // const type = match[1];
      const location = match[2];
      const text = match[3];

      // next get editor
      workspace.open(file, {
        split: 'right',
        searchAllPanes: true,
      }).then((editor) => {
        // create marker
        let start = (location.split(' - ')[0]).split(',');
        let end = (location.split(' - ')[1]).split(',');

        start = new Point(start[0] - 1, start[1] - 1);
        end = new Point(end[0] - 1, end[1] - 1);

        // set cursor to start position
        editor.setCursorBufferPosition(start);
        editor.scrollToCursorPosition();

        // create range object and markers
        const range = new Range(start, end);
        const marker = editor.markBufferRange(range);

        // remember marker
        this.tesslaMarkers.push(marker);

        // next create decoration
        editor.decorateMarker(marker, {
          type: 'highlight',
          class: 'tessla-syntax-error',
        });

        const tt = document.createElement('div');
        const ttLabel = document.createElement('span');
        const ttText = document.createElement('span');

        ttLabel.textContent = 'error';
        ttText.textContent = text;

        ttLabel.classList.add('error-label');
        tt.appendChild(ttLabel);
        tt.appendChild(ttText);

        const tooltip = editor.decorateMarker(marker, {
          type: 'overlay',
          class: 'tessla-syntax-tooltip',
          item: tt,
          position: 'tail',
        });

        // remember decoration for later
        this.tesslaTooltipDecorations.push(tooltip);

        // add a gutter to the opened file
        let gutter = editor.gutterWithName('tessla-error-gutter');
        if (!gutter) {
          gutter = editor.addGutter({
            name: 'tessla-error-gutter',
            priority: 1000,
            visible: true,
          });
        }

        gutter.decorateMarker(marker, {
          type: 'gutter',
          class: 'tessla-syntax-dot',
        });
      });
    }
  }

  /**
   * Hides the error markes from the current workspace
   * @return {void}
   */
  onHideErrorMarkers() {
    //  skip the rest of this method if there are no markers
    if (this.tesslaMarkers.length === 0) {
      return;
    }

    // destroy each marker
    this.tesslaTooltipDecorations.forEach((decoration) => {
      decoration.destroy();
    });

    // remove markers from array
    this.tesslaTooltipDecorations = [];
  }

  /**
   * Disables all buttons except the stop button
   * @return {void}
   */
  disableButtons() {
    this.toolBarButtons.BuildAndRunCCode.setEnabled(false);
    this.toolBarButtons.BuildCCode.setEnabled(false);
    this.toolBarButtons.RunCCode.setEnabled(false);
    this.toolBarButtons.BuildAndRunProject.setEnabled(false);
  }

  /**
   * Enables all buttons except the stop button
   * @return {void}
   */
  enableButtons() {
    this.toolBarButtons.BuildAndRunCCode.setEnabled(true);
    this.toolBarButtons.BuildCCode.setEnabled(true);
    this.toolBarButtons.RunCCode.setEnabled(true);
    this.toolBarButtons.BuildAndRunProject.setEnabled(true);
  }

  /**
   * Enables the stop button
   * @return {void}
   */
  enableStopButton() {
    this.toolBarButtons.Stop.setEnabled(true);
  }

  /**
   * Dsiables the stop button
   * @return {void}
   */
  disableStopButton() {
    this.toolBarButtons.Stop.setEnabled(false);
  }

  /**
   * Removes the markers from the TeSSLa source file
   * @return {void}
   */
  removeTeSSLaSourceMarkers() {
    this.tesslaMarkers.forEach((marker) => { marker.destroy(); });
    this.tesslaMarkers = [];
    this.tesslaTooltipDecorations = [];
  }

  /**
   * Saves all open editors and the active one at last.
   * @return {void}
   */
  saveEditors() {
    // Save all other text editors
    const activeEditor = atom.workspace.getActiveTextEditor();
    const currentProjPath = this.activeProject.projPath;

    // iterate over all editors in the current workspace
    atom.workspace.getTextEditors().forEach((editor) => {
      if (typeof editor.getPath() !== 'undefined' && editor.getPath() !== this.activeProject.projPath) {
        editor.save();
      }
    });

    // then save currently active text editor
    if (typeof activeEditor !== 'undefined') {
      activeEditor.save();
    }

    // restore the correct project path
    this.activeProject.setProjPath(currentProjPath);
  }
}
