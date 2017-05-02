'use babel';

import $ from 'jquery';
import electron from 'electron';
import fs from 'fs';

/**
 * Represents the message panel on the buttom of the text-editor view
 * @author Denis-Michael Lux <denis.lux@icloud.com>
 */
export default class TeSSLaMessagePanel {

  /**
   * Constructs the message panel and sets all needed listeners
   * @constructor
   * @param {Emitter} emitter - The global emitter object that is connected to
   * all other objects in this project.
   */
  constructor(emitter) {
    // save emitter object in own instance variable
    this.emitter = emitter;

    // init components
    const $clearBtn = $('<button>', { id: 'tessla-btn-clear', class: 'ion-trash-a' });
    const $closeBtn = $('<button>', { id: 'tessla-btn-close', class: 'ion-android-close' });
    const $saveBtn = $('<button>', { id: 'tessla-btn-save', class: 'ion-compose' });

    const $menu = $('<div>', { id: 'tessla-message-panel-menu' });
    $menu.append($closeBtn);
    $menu.append($clearBtn);
    $menu.append($saveBtn);
    $menu.append($('<div>', { class: 'tessla-cb' }));

    const $tabs = $('<ul>', { id: 'tessla-message-panel-tabs' });
    $tabs.append($('<li>', { id: 'console-output', class: 'active' }).append('<span>0</span>Console'));
    $tabs.append($('<li>', { id: 'c-error-output' }).append('<span>0</span>Errors (C)'));
    $tabs.append($('<li>', { id: 'tessla-error-output' }).append('<span>0</span>Errors (TeSSLa)'));
    $tabs.append($('<li>', { id: 'warning-output' }).append('<span>0</span>Warnings'));
    $tabs.append($('<li>', { id: 'workflow-output' }).append('<span>0</span>Log'));
    const $tabReiters = $tabs.children();

    const $consoleOutput = $('<div>', { id: 'console-output' }).append($('<div>', { class: 'view-table' }));
    const $reiter = $('<div>', { id: 'tessla-message-panel-body-wrapper', tabindex: '-1' });
    $reiter.append($consoleOutput);
    $reiter.append($('<div>', { id: 'c-error-output' }).append($('<div>', { class: 'view-table' })));
    $reiter.append($('<div>', { id: 'tessla-error-output' }).append($('<div>', { class: 'view-table' })));
    $reiter.append($('<div>', { id: 'warning-output' }).append($('<div>', { class: 'view-table' })));
    $reiter.append($('<div>', { id: 'workflow-output' }).append($('<div>', { class: 'view-table' })));

    this.$wrapper = $('<div>', { id: 'tessla-message-panel-wrapper' });
    this.$wrapper.append($menu);
    this.$wrapper.append($tabs);
    this.$wrapper.append($reiter);

    // now put wrapper into an own bottom panel
    atom.workspace.addBottomPanel({
      item: this.$wrapper.get(0),
      priority: -1000,
      visible: true,
    });

    // define panel stream wrappers
    this.consoleWrapper = $('#tessla-message-panel-body-wrapper > div#console-output > div.view-table');
    this.cerrorWrapper = $('#tessla-message-panel-body-wrapper > div#c-error-output > div.view-table');
    this.terrorWrapper = $('#tessla-message-panel-body-wrapper > div#tessla-error-output > div.view-table');
    this.warningsWrapper = $('#tessla-message-panel-body-wrapper > div#warning-output > div.view-table');
    this.logWrapper = $('#tessla-message-panel-body-wrapper > div#workflow-output > div.view-table');

    // store needed elements
    this.$panel = this.$wrapper.parent();

    // show the correct pre container
    $consoleOutput.show();

    // allow using native key bindings on message panel
    this.$wrapper.parent().addClass('native-key-bindings');

    // bind emitter events BEFORE emitting own events. The on method works
    // synchronously so if there is no binding yet the emit does nothing...
    this.onHide = this.onHide.bind(this);
    this.onShow = this.onShow.bind(this);
    this.onToggle = this.onToggle.bind(this);
    this.onAddConsoleText = this.onAddConsoleText.bind(this);
    this.onAddCErrorText = this.onAddCErrorText.bind(this);
    this.onAddTeSSLaErrorText = this.onAddTeSSLaErrorText.bind(this);
    this.onAddWarningText = this.onAddWarningText.bind(this);
    this.onAddLogText = this.onAddLogText.bind(this);

    this.emitter.on('add-console-text', this.onAddConsoleText);
    this.emitter.on('add-c-error-text', this.onAddCErrorText);
    this.emitter.on('add-tessla-error-text', this.onAddTeSSLaErrorText);
    this.emitter.on('add-warning-text', this.onAddWarningText);
    this.emitter.on('add-log-text', this.onAddLogText);
    this.emitter.on('clear-active-reiter', this.onClear);
    this.emitter.on('hide-message-panel', this.onHide);
    this.emitter.on('show-message-panel', this.onShow);
    this.emitter.on('toggle-message-panel', this.onToggle);

    // emit ready state to emitter this will end up by getting an on event for
    // setting the message text of the console panel. Because of that this line
    // of code must be placed after the on binding for adding messages to the
    // panels
    this.emitter.emit('created-message-panel', this.$panel.get(0));

    // bind events and add some listeners for buttons presses and other events
    this.onMouseDown = this.onMouseDown.bind(this);
    this.onMouseMove = this.onMouseMove.bind(this);
    this.onMouseUp = this.onMouseUp.bind(this);

    $menu.mousedown(this.onMouseDown);
    $(document).mousemove(this.onMouseMove);
    $(document).mouseup(this.onMouseUp);

    // add button listeners
    this.onSave = this.onSave.bind(this);

    $clearBtn.click(this.onClear);
    $closeBtn.click(this.onHide);
    $saveBtn.click(this.onSave);

    // add tab listeners
    $tabReiters.click(this.onChangeTab);
  }

  /**
   * Adds a specific text to the 'console'-stream of the message panel
   * @param {string} text - A text that can contain special characters. HTML
   * tags will be printed as text not as HTML elements.
   * @return {void}
   */
  onAddConsoleText(text) {
    // create a new line
    const $line = $('<div>', { class: 'line' });

    // set line properties
    $line.append($('<span>', { class: 'time', text: this.getCurrentTime() }));
    $line.append($('<span>', { class: 'text' }).text(text));

    // append line to console
    this.consoleWrapper.append($line);

    // scroll to bottom
    this.consoleWrapper.scrollTop(this.consoleWrapper.prop('scrollHeight'));

    // tab notification
    const notification = $('#tessla-message-panel-tabs > #console-output > span');

    if (!notification.parent().hasClass('active')) {
      notification.addClass('tessla-error-notification-success').text(parseInt(notification.text(), 10) + 1);
    }
  }

  /**
   * Adds a specific text to the 'error (c)'-stream of the message panel
   * @param {string} text - A text that can contain special characters. HTML
   * tags will be printed as text not as HTML elements.
   * @return {void}
   */
  onAddCErrorText(text) {
    // create a new line
    const $line = $('<div>', { class: 'line' });

    $line.append($('<span>', { class: 'time', text: this.getCurrentTime() }));
    $line.append($('<span>', { class: 'text' }).text(text));

    // add line to panel
    this.cerrorWrapper.append($line);

    // scroll to bottom
    this.cerrorWrapper.scrollTop(this.cerrorWrapper.prop('scrollHeight'));

    // tab notification
    const notification = $('#tessla-message-panel-tabs > #c-error-output > span');

    if (!notification.parent().hasClass('active')) {
      notification.addClass('tessla-error-notification-error').text(parseInt(notification.text(), 10) + 1);
    }
  }

  /**
   * Adds a specific text to the 'error (TeSSLa)'-stream of the message panel
   * @param {string} text - A text that can contain special characters. HTML
   * tags will be printed as text not as HTML elements.
   * @return {void}
   */
  onAddTeSSLaErrorText(text) {
    // create a new line
    const $line = $('<div>', { class: 'line' });

    // define line contents
    $line.append($('<span>', { class: 'time', text: this.getCurrentTime() }));
    $line.append($('<span>', { class: 'text' }).text(text));

    // append line to wrapper
    this.terrorWrapper.append($line);

    // scroll to bottom
    this.terrorWrapper.scrollTop(this.terrorWrapper.prop('scrollHeight'));

    // tab notification
    const notification = $('#tessla-message-panel-tabs > #tessla-error-output > span');

    if (!notification.parent().hasClass('active')) {
      notification.addClass('tessla-error-notification-error').text(parseInt(notification.text(), 10) + 1);
    }
  }

  /**
   * Adds a specific text to the 'warnings'-stream of the message panel
   * @param {string} text - A text that can contain special characters. HTML
   * tags will be printed as text not as HTML elements.
   * @return {void}
   */
  onAddWarningText(text) {
    // create a new line
    const $line = $('<div>', { class: 'line' });

    // define line contents
    $line.append($('<span>', { class: 'time', text: this.getCurrentTime() }));
    $line.append($('<span>', { class: 'text' }).text(text)); // we use .text() because it will escape HTML chars

    // append line to wrapper
    this.warningsWrapper.append($line);

    // scroll to bottom
    this.warningsWrapper.scrollTop(this.warningsWrapper.prop('scrollHeight'));

    // tab notification
    const notification = $('#tessla-message-panel-tabs > #warning-output > span');

    if (!notification.parent().hasClass('active')) {
      notification.addClass('tessla-error-notification-warning').text(parseInt(notification.text(), 10) + 1);
    }
  }

  /**
   * Adds a specific text to the 'warnings'-stream of the message panel
   * @param {string} text - A text that can contain special characters. HTML
   * tags will be printed as text not as HTML elements.
   * @return {void}
   */
  onAddLogText({ label, text }) {
    // create a new line
    const $line = $('<div>', { class: 'line' });

    // define line contents
    $line.append($('<span>', { class: 'time', text: this.getCurrentTime() }));
    $line.append($('<span>', { class: 'label' }).append($('<span>', { class: label, text: label })));
    $line.append($('<span>', { class: 'text' }).text(text));

    // append line to wrapper
    this.logWrapper.append($line);

    // scroll to bottom
    this.logWrapper.scrollTop(this.logWrapper.prop('scrollHeight'));

    // tab notification
    const notification = $('#tessla-message-panel-tabs > #workflow-output > span');

    if (!notification.parent().hasClass('active')) {
      notification.addClass('tessla-error-notification-workflow').text(parseInt(notification.text(), 10) + 1);
    }
  }

  /**
   * Clears the currently active stream in the message panel
   * @return {void}
   */
  onClear() {
    $('#tessla-message-panel-body-wrapper > div:visible > div.view-table').text('');
  }

  /**
   * Hides the message panel by slide it down to the viewport edge
   * @return {void}
   */
  onHide() {
    this.$panel.animate({
      height: 'hide',
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Shows the message panel by slide it up from the lower edge of the viewport
   * @return {void}
   */
  onShow() {
    this.$panel.animate({
      height: 'show',
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Toggles the message panel bei either slide the message panel up or down
   * @return {void}
   */
  onToggle() {
    this.$panel.animate({
      height: 'toggle',
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true,
    });
  }

  /**
   * Contains behavior for resizing the message panel by dragging the clicked mouse
   * @param {Event} event - An object containing information about the click event
   * @return {void}
   */
  onMouseDown(event) {
    // remember the mousedown position
    this.mousedown = true;
    this.mousedownY = event.pageY;
    this.originalH = $('#tessla-message-panel-body-wrapper > div:visible').height();

    // prevent slowing atom down by propagating event through DOM and prevent
    // default event behavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Fixes the height of all elements after releasing the mouse
   * @param {Event} event - An object containing information about the click event
   * @return {void}
   */
  onMouseUp(event) {
    this.mousedown = false;

    // set the height of the visible pre tag to all other pre tags
    const visiblePre = $('#tessla-message-panel-body-wrapper > div:visible');
    const otherPres = $('#tessla-message-panel-body-wrapper > div');

    otherPres.height(visiblePre.height());

    // prevent slowing atom down by propagating event through DOM and prevent
    // default event behavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Contains behavoir of dragging the clicked mouse. Resizes the message panel on the fly
   * @param {Event} event - An object containing information about the mouse event
   * @return {void}
   */
  onMouseMove(event) {
    if (!this.mousedown) {
      return;
    }

    // set new height
    $('#tessla-message-panel-body-wrapper > div').height((this.originalH + this.mousedownY) - event.pageY);

    // prevent slowing atom down by propagating event through DOM and prevent
    // default event behavior
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Saves the content of the current message panel stream
   * @return {void}
   */
  onSave() {
    // get rows of the current stream
    const rows = $('#tessla-message-panel-body-wrapper > div:visible > div').children();

    // variable that holds the full content
    const content = {};
    let output = '';

    $.each(rows, (outerkey, row) => {
      // find time element
      const timeEl = $(row).find('.time');
      const time = timeEl.text();

      // if this time is not already stored create new array
      if (!(time in content)) {
        content[time] = [];
      }

      // create a row element
      const rowObj = [];

      // now add text of other columns to content
      $.each($(timeEl).siblings(), (innerKey, col) => {
        rowObj.push($(col).text());
      });

      // add row to content object
      content[time].push(rowObj);
    });

    // now translate obejct into string
    Object.keys(content).forEach((key) => {
      const value = content[key];

      output += '\n';
      output += key;
      output += ':\n';

      // iterate ofer each entry
      value.forEach((row) => {
        row.forEach((col) => {
          output += col;
          output += ' ';
        });

        output += '\n';
      });
    });

    // create a save dialog
    const app = electron.remote;
    const dialog = app.dialog;
    const self = this;

    // show a save dialog
    dialog.showSaveDialog((filename) => {
      if (filename === undefined) {
        // show warnings text in message panel
        self.onAddWarningText('You did not save the file');
      } else {
        // write file to disc
        fs.writeFile(filename, output, (err) => {
          // if there were errors show them
          if (err) {
            self.onAddWarningText(`An error ocurred creating the file ${err.message}`);
          }
        });
      }
    });
  }

  /**
   * Contains behavior when the tab in the message panel changed
   * @return {void}
   */
  onChangeTab() {
    // remove notifications from this tab
    $(this).find('span')
      .removeClass('tessla-error-notification-success')
      .removeClass('tessla-error-notification-error')
      .removeClass('tessla-error-notification-warning')
      .removeClass('tessla-error-notification-workflow')
      .text('0');

    // get id of elements to show
    const showId = $(this).attr('id');
    $(this).addClass('active');
    $(this).siblings().removeClass('active');

    // next stage is getting the element with this id
    const pre = $(`div#${showId}`);
    pre.show();
    pre.siblings().hide();

    // scroll to bottom
    pre.scrollTop(pre.prop('scrollHeight'));
  }

  /**
   * Destroys the message panel
   * @return {void}
   */
  destroy() {
    this.$panel.remove();
  }

  /**
   * Provides the current time in 'HH:SS' format
   * @return {string} The current time in format 'HH:SS'
   */
  getCurrentTime() {
    return new Date().toLocaleTimeString('en-US', { hour12: false, hour: 'numeric', minute: 'numeric' });
  }
}
