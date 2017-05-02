'use babel';

import { Range, Point } from 'atom';

/**
 * A manager class that will show different notifications.
 * @author Denis-Michael Lux <denis.lux@icloud.com>
 */
export default class TeSSLaViewManager {

  /**
   * @constructor
   * @param {Emitter} emitter - A project global emitter class that will dispatch events
   * triggered by other components
   * @return {void}
   */
  constructor(emitter) {
    this.emitter = emitter;

    // an array of markers added to the text editor
    this.tesslaMarkers = [];
    this.tesslaUnsedFunctionMarkers = [];
    this.tesslaTooltipDecorations = [];

    // define atom variables
    this.notifications = atom.notifications;

    // set tool-bar buttons object to null
    this.btns = null;

    // bind self reference to methods
    this.onHighlightUnusedFunctions = this.onHighlightUnusedFunctions.bind(this);
    this.onHideErrorMarkers = this.onHideErrorMarkers.bind(this);
    this.highlightTeSSLaError = this.highlightTeSSLaError.bind(this);

    // set listeners
    this.emitter.on('distribute-unused-functions', this.onHighlightUnusedFunctions);
    this.emitter.on('cursor-changed-in-file', this.onHideErrorMarkers);
    this.emitter.on('distribute-tool-bar-buttons', (btns) => {
      this.btns = btns;
    });
  }

  /**
   * Shows a notification that there is no active project in workspace
   * @return {void}
   */
  showNoProjectNotification() {
    // show notification to user
    const message = 'There is no active project in your workspace. Open and activate at least one file of the project you want to compile and run in your workspace.';

    // show notification
    this.notifications.addError('Unable to compile and run C code', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message);
  }

  /**
   * Shows a notification that there are no compileable C files in the project directory
   * @return {void}
   */
  showNoCompilableCFilesNotification() {
    // show notification to user
    const message = 'There are no C files to compile in this project. Create at least one C file in this project containing a main function to build a runable binary.';

    // show notification
    this.notifications.addError('Unable to compile C files', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-c-error-text', message);
  }

  /**
   * Shows a notification that indicates that there is no executable binary in this project
   * @return {void}
   */
  showNoCBinaryToExecuteNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There is no C binary in the build directory which can be executed. You first have to build your C code to generate a binary.';

    // show notification
    this.notifications.addError('Unable to run binary', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-c-error-text', message);
  }

  /**
   * Shows a notification that indicates that the split view could not be set up
   * @return {void}
   */
  showNotSetUpSplitViewNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There are no ".tessla" and ".c" files to put into split view in the current project. Please open at least one file of your project and activate it in workspace to properly set up the split view. The split view can be set up by right click onto your source file in the text editor and select "Set up TeSSLa split view" in the context menu.';

    // show notification
    this.notifications.addWarning('Could not set up the split view', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-warning-text', message);
  }

  /**
   * Shows a notification that there was no TeSSLa JSON found in the project
   * @return {void}
   */
  showNoTeSSLaJSONFoundNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'No TeSSLa JSON file found!';

    // show notification
    this.notifications.addError('Unable to find TeSSLa JSON file', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message);
  }

  /**
   * Shows a notification that the split view could not be set up due to missing project
   * @return {void}
   */
  showNoActiveProjectForSplitViewNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'No Project currently active. To set up the split view at least one file should be active for setting up the split view';

    // show notification
    this.notifications.addWarning('Could not set up the split view', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-warning-text', message);
  }

  /**
   * Shows a notification that indicates that there is currently a process running
   * @return {void}
   */
  showCurrentlyRunningProcessNotification() {
    // set up a message variable containing the text shown to the user
    const message = 'There is a process that is currently running. A new action can only be performed if there is no action currently running.';

    // show notification
    this.notifications.addWarning('Unable to perform action', {
      detail: message,
    });

    // emit an event for inserting text into console
    this.emitter.emit('add-console-text', message);
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
    this.btns.BuildAndRunCCode.setEnabled(false);
    this.btns.BuildCCode.setEnabled(false);
    this.btns.RunCCode.setEnabled(false);
    this.btns.BuildAndRunProject.setEnabled(false);
  }

  /**
   * Enables all buttons except the stop button
   * @return {void}
   */
  enableButtons() {
    this.btns.BuildAndRunCCode.setEnabled(true);
    this.btns.BuildCCode.setEnabled(true);
    this.btns.RunCCode.setEnabled(true);
    this.btns.BuildAndRunProject.setEnabled(true);
  }

  /**
   * Enables the stop button
   * @return {void}
   */
  enableStopButton() {
    this.btns.Stop.setEnabled(true);
  }

  /**
   * Dsiables the stop button
   * @return {void}
   */
  disableStopButton() {
    this.btns.Stop.setEnabled(false);
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
}
