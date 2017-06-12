'use babel';

import { EditorView, TextEditorView, TextEditor, TextBuffer } from 'atom';

export default class MessageView {

  constructor(config) {
    // store values
    this.title = config.title;
    this.URI = config.URI;

    // create element content
    this.element = document.createElement('div');
    this.element.classList.add('message-view-wrapper');

    // add filter container to the top of the message view
    const filter = document.createElement('div');
    filter.classList.add('filter-container');

    // create an input for searching words
    const searchField = document.createElement('input');
    searchField.type = 'search';
    searchField.placeholder = 'Filter';
    searchField.classList.add('input-search', 'native-key-bindings');
    filter.appendChild(searchField);

    // add a clear button to the filter
    const clearBtn = document.createElement('a');
    clearBtn.classList.add('btn', 'icon', 'icon-file-text', 'inline-block-tight', 'float-right');
    clearBtn.innerHTML = 'clear';
    filter.appendChild(clearBtn);

    // add a save button to the filter
    const saveBtn = document.createElement('a');
    saveBtn.classList.add('btn', 'icon', 'icon-desktop-download', 'inline-block-tight');
    saveBtn.innerHTML = 'save';
    filter.appendChild(saveBtn);

    // add filter container to the panel
    this.element.appendChild(filter);

    // append nothing to show notification
    const notification = document.createElement('div');
    notification.classList.add('align-center', 'no-data-hint');
    notification.innerHTML = 'No data to show';

    this.element.appendChild(notification);

    // fill table with header elements
    const tableWrapper = document.createElement('div');
    tableWrapper.classList.add('table-wrapper');

    const table = document.createElement('div');
    table.classList.add('table', 'native-key-bindings');
    table.tabIndex = -1;

    tableWrapper.appendChild(table);

    // append table to wrapper
    this.element.appendChild(tableWrapper);

    // set listeners
    this.saveContent = this.saveContent.bind(this);
    saveBtn.addEventListener('click', this.saveContent);

    this.clearContent = this.clearContent.bind(this);
    clearBtn.addEventListener('click', this.clearContent);

    this.onFilter = this.onFilter.bind(this);
    searchField.addEventListener('input', () => this.onFilter(searchField.value));
  }

  addEntry(text) {
    const noDataHint = this.element.getElementsByClassName('no-data-hint')[0];

    if (noDataHint) {
      noDataHint.remove();
    }

    const entry = document.createElement('div');
    entry.classList.add('tr');

    const time = document.createElement('div');
    time.classList.add('td', 'message-view', 'align-center', 'w-100px');
    time.innerHTML = this.getTime();

    const message = document.createElement('div');
    message.classList.add('td', 'message-view', 'lr-padding-10px');
    message.innerHTML = text;

    entry.appendChild(message);
    entry.appendChild(time);

    const table = this.element.getElementsByClassName('table')[0];

    if (table) {
      table.appendChild(entry);
    }

    // scroll to bottom
    table.parentElement.scrollTop = table.parentElement.scrollHeight;
  }

  saveContent() {
    // console.log('save contents');
    // console.log(this.element);
  }

  clearContent() {
    const table = this.element.getElementsByClassName('table')[0];

    while (table.firstChild) {
      table.removeChild(table.firstChild);
    }

    if (this.element.getElementsByClassName('no-data-hint')[0]) {
      return;
    }

    const notification = document.createElement('div');
    notification.classList.add('align-center', 'no-data-hint');
    notification.innerHTML = 'No data to show';

    this.element.insertBefore(notification, this.element.getElementsByClassName('table-wrapper')[0]);
  }

  getTime() {
    const d = new Date();

    const hours = d.getHours() < 10 ? `0${d.getHours()}` : d.getHours();
    const minutes = d.getMinutes() < 10 ? `0${d.getMinutes()}` : d.getMinutes();
    const seconds = d.getSeconds() < 10 ? `0${d.getSeconds()}` : d.getSeconds();

    let millis = d.getMilliseconds() < 10 ? `0${d.getMilliseconds()}` : d.getMilliseconds();
    millis = millis < 100 ? `${millis}0` : millis

    return `${hours}:${minutes}:${seconds}.${millis}`;
  }

  getTitle() {
    return this.title;
  }

  getURI() {
    return this.URI;
  }

  getDefaultLocation() {
    return 'bottom';
  }

  getAllowedLocations() {
    return ['bottom', 'center'];
  }

  destroy() {
    this.element.remove()
  }

  onFilter(filter) {
    const table = this.element.getElementsByClassName('table')[0]
    const entries = table.children;

    for (const idx in entries) {
      const entry = entries[idx];

      if (entry && entry.children) {
        //console.log(entries[idx]);
        //console.log(entries[idx].children);
        const left = entry.children[0];
        const right = entry.children[1];
        if (left.innerHTML.indexOf(filter) !== -1 || right.innerHTML.indexOf(filter) !== -1) {
          entry.style.display = 'table-row';
        } else {
          entry.style.display = 'none';
        }
      }
    }
  }
}
