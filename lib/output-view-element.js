'use babel';

export default class OutputViewElement {

  constructor(name, content) {
    const itemWrapper = document.createElement('li');
    itemWrapper.classList.add('list-nested-item', 'collapsed');

    let item;

    if (content.length > 0) {
      item = document.createElement('div');
    } else {
      item = document.createElement('li');
    }

    item.classList.add('list-item');

    const itemText = document.createElement('span');
    itemText.classList.add('icon', 'inline-block', 'output-element-wrapper');

    if (content.length > 0) {
      itemText.classList.add('icon-eye');
      //itemText.innerHTML = `${name} (cnt: ${content.length})`;

      // create to elements
      // const flexContainer = document.createElement('div');
      // flexContainer.classList.add('display-flex', 'output-element');

      // const eye = document.createElement('span');
      // eye.classList.add('ion-eye');

      const identifier = document.createElement('span');
      identifier.innerHTML = `${name}`;

      const cnt = document.createElement('span');
      cnt.classList.add('itshape', 'subtle', 'align-right');
      cnt.innerHTML = `(cnt: ${content.length})`;

      // flexContainer.appendChild(eye);
      // flexContainer.appendChild(identifier);
      // flexContainer.appendChild(cnt);
      // itemText.appendChild(flexContainer);
      itemText.appendChild(identifier);
      itemText.appendChild(cnt);
    } else {
      itemText.classList.add('icon-circle-slash', 'subtle');
      itemText.innerHTML = `${name}`;
    }

    item.appendChild(itemText);

    // create sublist
    const sublist = document.createElement('ul');
    sublist.classList.add('list-tree', 'has-flat-children');

    content.forEach(value => {
      const sublistItem = document.createElement('li');
      sublistItem.classList.add('list-item');

      const left = document.createElement('span');
      left.classList.add('left-col');
      left.innerHTML = `${value.formattedTime}:`;

      const right = document.createElement('span');
      right.classList.add('right-col');
      right.innerHTML = `${value.value}`;

      sublistItem.appendChild(left);
      sublistItem.appendChild(right);
      sublist.appendChild(sublistItem);
    });

    itemWrapper.appendChild(item);
    itemWrapper.appendChild(sublist);

    if (content.length > 0) {
      this.element = itemWrapper;
    } else {
      this.element = item;
    }

    // add click event listener
    itemWrapper.addEventListener('click', () => this.onClick(itemWrapper));
  }

  onClick(self) {
    if (self.classList.contains('collapsed')) {
      self.classList.remove('collapsed');
    } else {
      self.classList.add('collapsed');
    }
  }
}
