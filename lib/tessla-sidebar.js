'use babel';

import $ from 'jquery';
import scanFolder from 'scan-folder';
import TeSSLaFileManager from './tessla-file-manager';

/**
 * A class representing the sidebar.
 * @author Denis-Michael Lux <denis.lux@icloud.com>
 */
export default class TeSSLaSidebar {

  /**
   * Constructs the sidebar and builds all GUI components
   * @constructor
   * @param {Emitter} emitter - The project global emitter object that will dispatch events
   * @return {void}
   */
  constructor(emitter) {
    // store project global emitter
    this.emitter = emitter;

    // define atom variables
    const workspace = atom.workspace;

    // set up sidebar
    const $resizer = $('<div>', { class: 'resizer' });

    // create the C list stuff
    const $headline1 = $('<h2>', { text: 'C functions from C sources' });
    this.$listC = $('<ul>', { class: 'list-c-function' });
    this.$listC.append($('<li>', { class: 'hint', text: 'No functions found' }));

    // create the TeSSLa list stuff
    const $headline2 = $('<h2>Missing C functions from TeSSLa sources</h2>');
    this.$listTeSSLa = $('<ul>', { class: 'list-tssl-functions' });
    this.$listTeSSLa.append($('<li>', { class: 'hint', text: 'No functions found' }));

    // create a wrapper element
    this.$functionsView = $('<div>', { id: 'tessla-sidebar' });
    this.$sidebar = $('<div>', { id: 'tessla-sidebar-wrapper' });

    // put all things together
    this.$functionsView.append($headline1);
    this.$functionsView.append(this.$listC);
    this.$functionsView.append($headline2);
    this.$functionsView.append(this.$listTeSSLa);

    // create table view
    this.$tableView = $('<div>', { id: 'tessla-table-view' });

    const $vertResizer = $('<div>', { class: 'vertical-resizer' });
    const $headline3 = $('<h2>', { text: 'Formatted TeSSLa output' });
    this.$listOutputs = $('<ul>', { class: 'list-formatted-output' });
    this.$listOutputs.append($('<li>', { class: 'hint', text: 'No output available' }));

    this.$tableView.append($headline3);
    this.$tableView.append(this.$listOutputs);

    // put two elements into sidebar
    this.$sidebar.append($resizer);
    this.$sidebar.append(this.$functionsView);
    this.$sidebar.append($vertResizer);
    this.$sidebar.append(this.$tableView);

    // now put wrapper into an own bottom panel
    workspace.addRightPanel({
      item: this.$sidebar.get(0),
      visible: true,
      priority: -100,
    });

    // store needed elements
    this.$panel = this.$sidebar.parent();

    // emit event that functions sidebar has been created
    this.emitter.emit('created-sidebar', this.$panel);

    // add emitter listeners
    this.onShow = this.onShow.bind(this);
    this.onHide = this.onHide.bind(this);
    this.onToggle = this.onToggle.bind(this);
    this.onUpdate = this.onUpdate.bind(this);
    this.onMouseDownColResizer = this.onMouseDownColResizer.bind(this);
    this.onMouseDownRowResizer = this.onMouseDownRowResizer.bind(this);
    this.onMouseMove = this.onMouseMove.bind(this);
    this.onMouseUp = this.onMouseUp.bind(this);
    this.onFormatOutput = this.onFormatOutput.bind(this);
    this.onToggleOutputSubList = this.onToggleOutputSubList.bind(this);

    this.emitter.on('show-sidebar', this.onShow);
    this.emitter.on('hide-sidebar', this.onHide);
    this.emitter.on('toggle-sidebar', this.onToggle);
    this.emitter.on('update-sidebar', this.onUpdate);
    this.emitter.on('active-project-changed', this.onUpdate);
    this.emitter.on('format-tessla-output', this.onFormatOutput);

    // bind events to resizer and document
    $resizer.mousedown(this.onMouseDownColResizer);
    $vertResizer.mousedown(this.onMouseDownRowResizer);
    $(document).mousemove(this.onMouseMove);
    $(document).mouseup(this.onMouseUp);
  }

  /**
   * Handles the mousedown event for the row resizer
   * @param {Event} event - The event containing information about the mousedown position etc.
   * @return {void}
   */
  onMouseDownRowResizer(event) {
    this.mouseDownRowResizer = true;
    this.mousedownY = event.pageY;
    this.originalH = this.$functionsView.outerHeight();

    // prevent slowing atom down by propagating event throuth DOM and prevent default event
    // beahavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Handles the mousedown event for the col resizer
   * @param {Event} event - The event containing information about the mousedown position etc.
   * @return {void}
   */
  onMouseDownColResizer(event) {
    // rememer the mousedown position
    this.mouseDownColResizer = true;
    this.mousedownX = event.pageX;
    this.originalW = this.$sidebar.width();

    // prevent slowing atom down by propagating event throuth DOM and prevent default event
    // beahavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Handles the Mouse up event
   * @param {Event} event - The event containing information about the mouseup position etc.
   * @return {void}
   */
  onMouseUp(event) {
    this.mouseDownColResizer = false;
    this.mouseDownRowResizer = false;

    // prevent slowing atom down by propagating event throuth DOM and prevent default event
    // beahavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Handles the mouse move event
   * @param {Event} event - The event containing information about the mousemove position etc.
   * @return {void}
   */
  onMouseMove(event) {
    if (this.mouseDownColResizer) {
      // set new width
      this.$sidebar.width((this.originalW + this.mousedownX) - event.pageX);

      // prevent slowing atom down by propagating event throuth DOM and prevent default event
      // beahavior
      event.preventDefault();
      event.stopPropagation();
    }

    if (this.mouseDownRowResizer) {
      // calc new height
      const newHeight = (this.originalH - this.mousedownY) + event.pageY;
      const sidebarHeight = this.$sidebar.height();

      if (newHeight < sidebarHeight - 150 && event.pageY > 150) {
        // set new height
        this.$functionsView.outerHeight(newHeight);

        // get new height ffor table view
        this.$tableView.outerHeight(sidebarHeight - newHeight);
      }

      // prevent slowing atom down by propagating event throuth DOM and prevent default event
      // beahavior
      event.preventDefault();
      event.stopPropagation();
    }
  }

  /**
   * Shows the sidebar in the workspace
   * @return {void}
   */
  onShow() {
    // define atom variables
    const config = atom.config;

    // animates the slide in
    this.$panel.animate({
      width: 'show',
    }, {
      duration: config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Hides the sidebar in the workspace
   * @return {void}
   */
  onHide() {
    // define atom variables
    const config = atom.config;

    // animates the slide out
    this.$panel.animate({
      width: 'hide',
    }, {
      duration: config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Toggles the sidebar in the workspace
   * @return {void}
   */
  onToggle() {
    // define atom variables
    const config = atom.config;

    // animates the toggle
    this.$panel.animate({
      width: 'toggle',
    }, {
      duration: config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Handler for the click element on the functions in the sidebar
   * @param {jQuery} functionElement - The element that was clicked
   * @param {Event} event - The click event
   * @return {void}
   */
  onElementClicked(functionElement, event) {
    // Define Atom variables
    const workspace = atom.workspace;
    const project = atom.project;

    // extract information
    let lineCol = functionElement.children().eq(3).text();
    lineCol = lineCol.substr(1, lineCol.length - 2).split(':');

    const line = parseInt(lineCol[0], 10) - 1;
    const col = parseInt(lineCol[1], 10);

    const file = functionElement.children().eq(4).text();

    // open the file and set cursor to the correct position
    const currentFile = workspace.getActiveTextEditor().getPath();
    const projectPath = project.relativizePath(currentFile)[0];

    const splitVar = file.substr(file.length - 2) === '.c' ? 'left' : 'right';

    workspace.open(`${projectPath}/${file}`, { split: splitVar, searchAllPanes: true }).then((editor) => {
      editor.setCursorBufferPosition([line, col]);
    });

    // prevent slowing atom down by propagating event throuth DOM and prevent default event
    // beahavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Controls the behavior that will hapen after adding a testcase from the sidebar
   * @param {jQuery} functionElement - The function that was selected in the sidebar
   * @param {Event} event - The click event that causes Atom to invoke this function
   * @param {string} projectPath - The path of to the current project directory
   * @return {void}
   */
  onCreateTestCaseClicked(functionElement, event, projectPath) {
    // Define Atom variables
    const workspace = atom.workspace;

    // get function and file name
    const functionName = functionElement.children().eq(2).text();

    // get tessla files
    const tesslaFile = scanFolder(projectPath, '.tessla', true, {
      dotFolder: false,
      dotFiles: false,
      modules: false,
    })[0];

    workspace.open(tesslaFile, { split: 'right', searchAllPanes: true }).then((editor) => {
      // first set cursor position to the end
      editor.setCursorBufferPosition([editor.getLineCount(), 0]);

      // next craft text that should be inserted
      let text = '\n--Inserted test case automatically in the first tessla file that was found';
      text += `\ndefine calls_${functionName} : Events<Unit> := function_calls("${functionName}")`;

      // try to insert text into file. If everything worked update sidebar
      if (editor.insertText(text, { select: true, autoIndent: true })) {
        // save editor
        editor.save();
      }
    });

    // prevent slowing atom down by propagating event throuth DOM and prevent default event
    // beahavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Updates the function sidebar including its sublists
   * @param {TeSSLaProject} activeProject - The project the sidebar should display
   * @return {void}
   */
  onUpdate(activeProject) {
    // do not update if the sidebar is hidden
    // if (this.$functionsView.is(':hidden')) {
    //   return
    // }

    // get list of all C files and the tessla file
    const cFiles = activeProject.cFiles ? activeProject.cFiles : [];
    const tesslaFiles = activeProject.tesslaFiles ? activeProject.tesslaFiles : [];

    // get array with c functions and tessla functions
    let cFunctions = [];
    let tesslaFunctions = [];
    const cFuncNames = {};

    // empty lists
    this.$listC.empty();
    this.$listTeSSLa.empty();

    // get all C functions form all c files
    cFiles.forEach((file) => {
      // first fetch all c function from the current file
      const functions = TeSSLaFileManager.collectCFunctionsFromSourceFile({
        sourceFile: file,
        projectPath: activeProject.projPath,
      });

      // merge all cFunctions from all files together
      cFunctions = cFunctions.concat(functions);

      // add a list item for each function
      functions.forEach((cFunction) => {
        // create the current list element
        const $listElement = $('<li>');
        const $testCaseButton = $('<button>', { class: 'ion-plus-circled' });
        const $indicator = $('<span>f', { text: 'f(x)' });
        const $name = $('<span>', { text: cFunction.functionName });
        const $filePath = $('<span>', { text: cFunction.fileName });
        const $occurence = $('<span>', { text: `(${cFunction.occurrence})` });
        const $cb = $('<div>', { class: 'cb' });

        // put all stuff together
        $listElement.append($testCaseButton);
        $listElement.append($indicator);
        $listElement.append($name);
        $listElement.append($occurence);
        $listElement.append($filePath);
        $listElement.append($cb);
        this.$listC.append($listElement);

        // add click listener to listElement
        const self = this;
        $listElement.click((event) => {
          self.onElementClicked($(this), event);
        });

        // add click listener to button
        $testCaseButton.click((event) => {
          self.onCreateTestCaseClicked($listElement, event, activeProject.projPath);
        });
      });
    });

    // next iterate over each TeSSLa file
    tesslaFiles.forEach((file) => {
      // first fetch all C function from the current TeSSLa file
      const functions = TeSSLaFileManager.collectCFunctionsFromSourceFile({
        sourceFile: file,
        projectPath: activeProject.projPath,
      });

      // remember TeSSLa functions
      tesslaFunctions = tesslaFunctions.concat(functions);

      // add a list item for list element
      functions.forEach((func) => {
        // create the current list element
        const $listElement = $('<li>');
        const $indicator = $('<span>', { class: 'tssl', text: 'f(x)' });
        const $name = $('<span>', { text: func });
        const $filePath = $('<span>');
        const $cb = $('<div>', { class: 'tessla-cb' });

        $listElement.append($indicator);
        $listElement.append($name);
        $listElement.append($filePath);
        $listElement.append($cb);
        this.$listTeSSLa.append($listElement);
      });
    });

    tesslaFunctions.forEach((tsslFunc) => {
      cFunctions.forEach((cFunc) => {
        // get names ans paths of files
        const cFnName = cFunc.functionName;
        const tFnName = tsslFunc;

        cFuncNames[cFnName] = cFnName;

        // var cFnPath = cFunc.fileName
        // var tFnPath = tsslFunc.fileName

        // test if function is in both lists available
        // if ( cFnName == tFnName && cFnPath == tFnPath ) {
        if (cFnName === tFnName) {
          // get element in list to give new color
          $.each(this.$listC.find('li'), (key, value) => {
            // get the name and the path of the current object
            const name = $(value).children().eq(2).text();

            // Attention: The path is needed when syntax as "main.c:fn" is accepted
            // Now we only check if the name of the function is equal
            // var path = $(value).children().eq(4).text()

            // if (name == cFnName && cFnPath == path) {
            if (name === cFnName) {
              // mark function as logged
              $(value).children().eq(1).addClass('tssl-logged');

              // remove test case button from element
              // var buttonWidth = $(value).children().eq(0).outerWidth(false)
              // $(value).children().eq(0).remove()

              // add a place holder to none clickable element
              // var placeholder = $('<div class='placeholder'></div>')
              // placeholder.width(buttonWidth)
              // $(value).prepend(placeholder)
            }
          });

          // last we have to hide the other elements
          $.each(this.$listTeSSLa.find('li'), (key, value) => {
            // get the name and the path of the current object
            const name = $(value).children().eq(1).text();

            // see above why we made a command from the following lines
            // var path = $(value).children().eq(2).text()
            // if (name == cFnName && cFnPath == path) {

            if (name === cFnName) {
              // remove the list element form the sidebar
              $(value).remove();
            }
          });
        }
      });
    });

    // append place holders to list if there are no files
    if (this.$listC.children().length === 0) {
      this.$listC.append($('<li>', { class: 'hint', text: 'No functions found' }));
    }

    if (this.$listTeSSLa.children().length === 0) {
      this.$listTeSSLa.append($('<li>', { class: 'hint', text: 'No functions found' }));
    }

    // resize elements
    this.resizeElements();

    // define array difference function
    Array.prototype.diff = function(a) {
      return this.filter((i) => { return a.indexOf(i) < 0; });
    };

    // create array from object
    const unusedFunctions = [];
    Object.keys(cFuncNames).forEach((key) => {
      unusedFunctions.push(key);
    });

    // get differences
    const difference = tesslaFunctions.diff(unusedFunctions);

    // distribute difference to all emitter listeners
    this.emitter.emit('distribute-unused-functions', {
      unusedFunctions: difference,
      tesslaFile: tesslaFiles,
    });
  }

  /**
   * Resizing the two seperate ares in the sidebar
   * @return {void}
   */
  resizeElements() {
    // get height of functions view
    const heightFunctionsView = this.$functionsView.outerHeight();
    const heightSidebar = this.$sidebar.height();

    // if max height of functions view is not reached
    if (heightFunctionsView < heightSidebar - 150) {
      // make table view fill space
      this.$tableView.outerHeight(heightSidebar - heightFunctionsView);
    } else { // if functions view is higher than max value
      // set functions view onto max value
      this.$functionsView.outerHeight(heightSidebar - 150);
      // set table view to difference
      this.$tableView.outerHeight(150);
    }
  }

  /**
   * Toggles the output sublist
   * @param {jQuery} $element - The label of the sublist that should be toggled
   * @return {void}
   */
  onToggleOutputSubList($element) {
    // Define Atom variables
    const config = atom.config;

    // change arrow icon of list element
    const $arrow = $('span:first', $element);

    // toggle arrow classes after animation is done
    if ($arrow.hasClass('ion-chevron-right')) {
      $arrow.removeClass('ion-chevron-right');
      $arrow.addClass('ion-chevron-down');

      // make element active
      $element.siblings().removeClass('active');
      $element.addClass('active');
    } else if ($arrow.hasClass('ion-chevron-down')) {
      $arrow.removeClass('ion-chevron-down');
      $arrow.addClass('ion-chevron-right');

      $element.removeClass('active');
    }

    // now show sublist
    $element.find('ul').animate({
      height: 'toggle',
    }, {
      duration: config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Formats given output and displays it as sublists in the sidebar
   * @param {Object} config - An object containing information about that should be displayed
   * @return {void}
   */
  onFormatOutput({ output }) {
    // first build regex
    const regex = /(.+)@(.+):(.+)/g;

    // array containing formatted lines
    const formatted = {};

    // next loop over matches
    output.forEach((line) => {
      // get the match
      let match;

      // loop over each match for the current line
      do {
        match = regex.exec(line);

        // if there was a match log groupes
        if (match) {
          // predefine date string variable
          let dateString;

          // change value of initial responses
          if (parseFloat(match[2]) === 0) {
            dateString = 'initially';
          } else {
            // format timestamp
            const date = new Date(parseFloat(match[2]) * 1000);
            // get components
            const hours = date.getHours() < 10 ? `0${date.getHours()}` : date.getHours();
            const minutes = date.getMinutes() < 10 ? `0${date.getHours()}` : date.getHours();
            const seconds = date.getSeconds() < 10 ? `0${date.getHours()}` : date.getHours();
            // put all things together
            dateString = `${hours}:${minutes}:${seconds}.${date.getMilliseconds()}`;
          }

          // push values into formatted array
          if (match[1] in formatted) {
            formatted[match[1]].push({
              time: parseFloat(match[2]),
              formattedTime: dateString,
              value: match[3],
            });
          } else {
            formatted[match[1]] = [{
              time: parseFloat(match[2]),
              formattedTime: dateString,
              value: match[3],
            }];
          }
        }
      } while (match);
    });

    // clear list
    this.$listOutputs.empty();

    // remember self reference
    const self = this;
    let countProps = 0;

    // now run over each property and first sort elements and then add elements to view
    Object.keys(formatted).forEach((key) => {
      // sort array by timestamp
      formatted[key].sort((a, b) => {
        return a.time - b.time;
      });

      // ok and the last step will be inserting values into list
      const $icon = $('<span>', { class: 'ion-chevron-right' });
      const $label = $('<span>', { text: key });
      const $counter = $('<span>', { class: 'cnt-values', text: `#${formatted[key].length}` });
      const $entry = $('<li>');
      const $sublist = $('<ul>');

      formatted[key].forEach((element) => {
        // create new list element
        const $listElement = $('<li>');
        $listElement.append($('<span>', { text: element.formattedTime }));
        $listElement.append($('<span>', { text: element.value }));
        $listElement.append($('<div>', { class: 'tessla-cb' }));

        // append element to sublist
        $sublist.append($listElement);
      });

      // set listener to list element
      $label.click(() => {
        self.onToggleOutputSubList($(this).parent());
      });

      $icon.click(() => {
        self.onToggleOutputSubList($(this).parent());
      });

      $entry.append($icon);
      $entry.append($label);
      $entry.append($counter);
      $entry.append($('<div>', { class: 'tessla-cb' }));
      $entry.append($sublist);
      this.$listOutputs.append($entry);

      // increase property counter
      countProps += 1;
    });

    if (countProps === 0) {
      this.$listOutputs.append($('<li>', { class: 'hint', text: 'No output available' }));
    }

    // now resize elements
    this.resizeElements();
  }

  /**
   * Destroys the sidebar
   * @return {void}
   */
  destroy() {
    this.$panel.remove();
  }
}
