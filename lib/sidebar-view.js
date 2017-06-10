'use babel';

import SidebarViewElement from './sidebar-view-element';
import FileManager from './file-manager';

export default class SidebarView {

  constructor(config) {
    this.title = config.title;
    this.URI = config.URI;
    this.viewManager = null;

    this.element = document.createElement('div');
    this.element.classList.add('sidebar-wrapper');

    // add header
    const header = document.createElement('h4');
    header.classList.add('align-center', 'block', 'highlight', 'padding-5px');
    header.innerHTML = 'C Functions'

    // add list
    const listWrapper = document.createElement('div');
    listWrapper.classList.add('list-wrapper');

    const list = document.createElement('ul');
    list.classList.add('list-group');

    const placeholder = document.createElement('span');
    placeholder.classList.add('placeholder');
    placeholder.innerHTML = 'No functions found';

    list.appendChild(placeholder);
    listWrapper.appendChild(list);

    this.element.appendChild(header);
    this.element.appendChild(listWrapper);
  }

  setViewManager(viewManager) {
    this.viewManager = viewManager;
  }

  addEntry({name, file, line, column, observed, exists}) {
    const entry = new SidebarViewElement({
      name,
      file,
      line: line.toString(),
      column: column.toString(),
      observed,
      exists,
      viewManager: this.viewManager,
    });
    const listGroup = this.element.getElementsByClassName('list-group')[0];
    const placeholder = listGroup.querySelector('.placeholder');

    listGroup.appendChild(entry.element);

    if (placeholder) {
      listGroup.removeChild(placeholder);
    }
  }

  clearEntries() {
    const listView = this.element.getElementsByClassName('list-group')[0];

    while (listView.hasChildNodes()) {
      listView.removeChild(listView.lastChild);
    }

    const placeholder = document.createElement('span');
    placeholder.classList.add('placeholder');
    placeholder.innerHTML = 'No functions found';

    listView.appendChild(placeholder);
  }

  getTitle() {
    return this.title;
  }

  getURI() {
    return this.URI;
  }

  getDefaultLocation() {
    return 'right';
  }

  getAllowedLocations() {
    return ['right', 'center', 'left'];
  }

  destroy() {
    this.element.remove()
  }

  update(activeProject) {
    // console.log("Update sidebar for functions");
    // get all c and tessla files
    const cFiles = activeProject.cFiles;
    const tFiles = activeProject.tesslaFiles;

    // delete all existing entries
    this.clearEntries();

    // skip the rest if there is no file given
    if (!cFiles && !tFiles) {
      return;
    }

    const cFunctions = [];
    const tFunctions = [];
    const list = [];

    // put C functions from C files into list
    cFiles.forEach(file => {
      FileManager.collectCFunctionsFromSourceFile({
        sourceFile: file,
        projectPath: activeProject.projPath,
      }).forEach(func => {
        list.push(func);
      })
    });

    // set attributes of each c file to not observed but exists
    list.forEach(cFile => {
      cFile.observed = false;
      cFile.exists = true;
    })

    // add each tessla file to the list that not occurs in a C file
    tFiles.forEach(file => {
      FileManager.collectCFunctionsFromSourceFile({
        sourceFile: file,
        projectPath: activeProject.projPath,
      }).forEach(func => {
        // check if the function is defined in the C files
        let definedInCFiles = false;

        list.forEach(listFunc => {
          if (listFunc.functionName === func.functionName) {
            //console.log(listFunc.functionName, func.functionName);
            definedInCFiles = true;
            listFunc.observed = true;
          }
        });

        if (!definedInCFiles) {
          func.exists = false;
          func.observed = false;
          list.push(func);
        }
      })
    });

    // now sort the list and then add entries
    list.sort((a, b) => {
      const keyA = a.functionName;
      const keyB = b.functionName;

      if (keyA < keyB) return -1;
      if (keyA > keyB) return +1;
      return 0;
    });

    // now iterate over list and add entries
    list.forEach(entry => {
      this.addEntry({
        name: entry.functionName,
        file: entry.fileName,
        line: entry.line,
        column: entry.column,
        observed: entry.observed,
        exists: entry.exists,
      });
    })
  }
}
