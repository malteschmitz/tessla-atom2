'use babel';

import scanFolder from 'scan-folder';

export default class SidebarViewElement {

  constructor({ name: name, file: file, line: line, column: col, observed: o, exists: e, viewManager: v }) {
    const itemWrapper = document.createElement('li');
    itemWrapper.classList.add('list-item', 'function-wrapper');

    // create add logo
    const addBtn = document.createElement('a');
    addBtn.classList.add('ion-plus-circled');

    const fxLabel = document.createElement('span');
    if (typeof o !== 'undefined' && o === true) {
      fxLabel.classList.add('text-info');
    } else if (typeof e !== 'undefined' && e === false) {
      fxLabel.classList.add('text-error');
      addBtn.classList.add('icon-invisible', 'cursor-default');
    } else {
      fxLabel.classList.add('text-success');
    }
    fxLabel.innerHTML = 'f(x)';

    const fxName = document.createElement('span');
    fxName.innerHTML = name;

    itemWrapper.appendChild(addBtn);
    itemWrapper.appendChild(fxLabel);
    itemWrapper.appendChild(fxName);

    if (line !== "" && col !== "") {
      const lineCol = document.createElement('span');
      lineCol.classList.add('align-right', 'itshape', 'subtle');
      lineCol.innerHTML = `${file} (l${line}:c${col})`;
      itemWrapper.appendChild(lineCol);
    }

    // itemWrapper.appendChild(item);
    this.element = itemWrapper;

    // listeners
    console.log(v);
    this.onAddTest = this.onAddTest.bind(this);
    addBtn.addEventListener('click', (event) => this.onAddTest({
      functionName: name,
      projectPath: v.activeProject.projPath,
    }, event));
  }

  onClick(self) {
    console.log("Test");

    if (self.classList.contains('collapsed')) {
      self.classList.remove('collapsed');
    } else {
      self.classList.add('collapsed');
    }
  }

  onAddTest({ functionName, projectPath }, event) {
    // Define Atom variables
    const workspace = atom.workspace;

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
}
