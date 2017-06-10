'use babel';

import OutputViewElement from './output-view-element';

export default class OutputView {

  constructor(config) {
    this.title = config.title;
    this.URI = config.URI;

    this.element = document.createElement('div');
    this.element.classList.add('output-wrapper');

    const toolbar = document.createElement('div');
    toolbar.classList.add('btn-toolbar');

    const btnGroup = document.createElement('div');
    btnGroup.classList.add('btn-group', 'float-right');

    const expandBtn = document.createElement('a');
    expandBtn.classList.add('btn');
    expandBtn.innerHTML = 'Expand All';

    const collapseBtn = document.createElement('a');
    collapseBtn.classList.add('btn');
    collapseBtn.innerHTML = 'Collapse All';

    btnGroup.appendChild(expandBtn);
    btnGroup.appendChild(collapseBtn);
    toolbar.appendChild(btnGroup);
    this.element.appendChild(toolbar);

    // add header
    const header = document.createElement('h4');
    header.classList.add('align-center', 'block', 'highlight', 'padding-5px');
    header.innerHTML = 'Output Streams'

    this.element.appendChild(header);

    const listTree = document.createElement('ul');
    listTree.classList.add('list-tree', 'has-collapsable-children');

    // add list wrapper
    const listWrapper = document.createElement('div');
    listWrapper.classList.add('list-wrapper');

    const placeholder = document.createElement('span');
    placeholder.classList.add('placeholder');
    placeholder.innerHTML = 'No functions found';

    listTree.appendChild(placeholder);
    listWrapper.appendChild(listTree);
    this.element.appendChild(listWrapper);

    const content = [];
    for (let i = 0; i < 100; i++) {
      content.push(['variable', `${i}`]);
    }

    this.onExpand = this.onExpand.bind(this);
    expandBtn.addEventListener('click', this.onExpand);

    this.onCollapse = this.onCollapse.bind(this);
    collapseBtn.addEventListener('click', this.onCollapse);
  }

  addEntry(identifier, content) {
    const entry = new OutputViewElement(identifier, content);
    const listTree = this.element.getElementsByClassName('list-tree')[0];
    const placeholder = listTree.querySelector('.placeholder');

    listTree.appendChild(entry.element);

    if (placeholder) {
      listTree.removeChild(placeholder);
    }
  }

  clearEntries() {
    const treeView = this.element.getElementsByClassName('list-tree')[0];

    while (treeView.hasChildNodes()) {
      treeView.removeChild(treeView.lastChild);
    }

    const placeholder = document.createElement('span');
    placeholder.classList.add('placeholder');
    placeholder.innerHTML = 'No functions found';

    treeView.appendChild(placeholder);
  }

  onExpand() {
    const list = this.element.getElementsByClassName('list-tree')[0];
    const listItems = list.children;

    for (let i = 0; i < listItems.length; i++) {
      console.log();
      if (listItems[i].classList.contains('list-nested-item') && listItems[i].classList.contains('collapsed')) {
        listItems[i].classList.remove('collapsed');
      }
    }
  }

  onCollapse() {
    const list = this.element.getElementsByClassName('list-tree')[0];
    const listItems = list.children;

    for (let i = 0; i < listItems.length; i++) {
      console.log();
      if (listItems[i].classList.contains('list-nested-item')) {
        listItems[i].classList.add('collapsed');
      }
    }
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

  update(output) {
    console.log("update output view");

    // first build regex
    const regex = /(.+)@(.+):(.+)/g;

    // array containing formatted lines
    const formatted = {};

    // next loop over matches
    output.forEach(line => {
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
    this.clearEntries();

    // remember self reference
    const self = this;
    let countProps = 0;

    // now run over each property and first sort elements and then add elements to view
    Object.keys(formatted).forEach((key) => {
      // sort array by timestamp
      formatted[key].sort((a, b) => {
        return a.time - b.time;
      });

      this.addEntry(key, formatted[key]);

      // formatted[key].forEach((element) => {
      //   // create new list element
      //   const $listElement = $('<li>');
      //   $listElement.append($('<span>', { text: element.formattedTime }));
      //   $listElement.append($('<span>', { text: element.value }));
      //   $listElement.append($('<div>', { class: 'tessla-cb' }));
      //
      //   // append element to sublist
      //   $sublist.append($listElement);
      // });
    });
  }
}
