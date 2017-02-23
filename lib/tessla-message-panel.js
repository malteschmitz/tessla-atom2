'use babel'

$ = jQuery = require('jquery')

export default class TeSSLaMessagePanel {

  constructor(emitter) {
    // save emitter object in own instance variable
    this.emitter    = emitter

    // init components
    var $clearBtn, $closeBtn, $saveBtn
    var $menu               = $('<div id="tessla-message-panel-menu"><div>')
    $menu.append( $closeBtn = $('<button id="tessla-btn-close" class="ion-android-close"></button>') )
    $menu.append( $clearBtn = $('<button id="tessla-btn-clear" class="ion-trash-a"></button>') )
    $menu.append( $saveBtn  = $('<button id="tessla-btn-save" class="ion-compose"></button>') )
    $menu.append( $('<div class="tessla-cb"></div>') )

    var $tabs = $('<ul id="tessla-message-panel-tabs"><ul>')
    $tabs.append( $('<li class="active" id="console-output"><span>0</span>Console</li>') )
    $tabs.append( $('<li id="c-error-output"><span>0</span>Errors (C)</li>') )
    $tabs.append( $('<li id="tessla-error-output"><span>0</span>Errors (TeSSLa)</li>') )
    $tabs.append( $('<li id="warning-output"><span>0</span>Warnings</li>') )
    $tabs.append( $('<li id="workflow-output"><span>0</span>Log</li>') )
    var $tabReiters = $tabs.children()

    var $consoleOutput
    var $reiter = $('<div id="tessla-message-panel-body-wrapper" tabindex="-1"><div>')
    $reiter.append( $consoleOutput = $('<pre id="console-output"></pre>') )
    $reiter.append( $('<pre id="c-error-output"></pre>') )
    $reiter.append( $('<pre id="tessla-error-output"></pre>') )
    $reiter.append( $('<pre id="warning-output"></pre>') )
    $reiter.append( $('<pre id="workflow-output"></pre>') )

    this.$wrapper = $('<div id="tessla-message-panel-wrapper"></div>')
    this.$wrapper.append( $menu )
    this.$wrapper.append( $tabs )
    this.$wrapper.append( $reiter )

    // now put wrapper into an own bottom panel
    atom.workspace.addBottomPanel({
      item:     this.$wrapper.get(0),
      priority: -1000,
      visible:  true
    })

    // store needed elements
    this.$panel = this.$wrapper.parent()

    // show the correct pre container
    $consoleOutput.show()

    // allow using native key bindings on message panel
    this.$wrapper.parent().addClass('native-key-bindings')

    // bind emitter events BEFORE emitting own events. The on method works
    // synchronously so if there is no binding yet the emit does nothing...
    this.onHide = this.onHide.bind(this)
    this.onShow = this.onShow.bind(this)
    this.onToggle = this.onToggle.bind(this)

    this.emitter.on('add-console-text',       this.onAddConsoleText)
    this.emitter.on('add-c-error-text',       this.onAddCErrorText)
    this.emitter.on('add-tessla-error-text',  this.onAddTeSSLaErrorText)
    this.emitter.on('add-warning-text',       this.onAddWarningText)
    this.emitter.on('add-log-text',           this.onAddLogText)
    this.emitter.on('clear-active-reiter',    this.onClear)
    this.emitter.on('hide-message-panel',     this.onHide)
    this.emitter.on('show-message-panel',     this.onShow)
    this.emitter.on('toggle-message-panel',   this.onToggle)

    // emit ready state to emitter this will end up by getting an on event for
    // setting the message text of the console panel. Because of that this line
    // of code must be placed after the on binding for adding messages to the
    // panels
    this.emitter.emit('created-message-panel', this.$panel.get(0))

    // bind events and add some listeners for buttons presses and other events
    this.onMouseDown  = this.onMouseDown.bind(this)
    this.onMouseMove  = this.onMouseMove.bind(this)
    this.onMouseUp    = this.onMouseUp.bind(this)

    $menu.mousedown(this.onMouseDown)
    $(document).mousemove(this.onMouseMove)
    $(document).mouseup(this.onMouseUp)

    // add button listeners
    this.onSave = this.onSave.bind(this)

    $clearBtn.click(this.onClear)
    $closeBtn.click(this.onHide)
    $saveBtn.click(this.onSave)

    // add tab listeners
    $tabReiters.click(this.onChangeTab)
  }

  onAddConsoleText(text) {
    // get element
    var cons = $('#tessla-message-panel-body-wrapper > pre#console-output')

    // append new text to console
    cons.text(cons.text() + text)

    // scroll to bottom
    cons.scrollTop(cons.prop('scrollHeight'))

    // tab notification
    var notification = $('#tessla-message-panel-tabs > #console-output > span')

    if ( !notification.parent().hasClass('active') ) {
      notification.addClass('tessla-error-notification-success').text(parseInt(notification.text()) + 1)
    }
  }

  onAddCErrorText(text) {
    // get element
    var cons = $('#tessla-message-panel-body-wrapper > pre#c-error-output')

    // append new text to console
    cons.text(cons.text() + text + '\n')

    // scroll to bottom
    cons.scrollTop(cons.prop('scrollHeight'))

    // tab notification
    var notification = $('#tessla-message-panel-tabs > #c-error-output > span')

    if ( !notification.parent().hasClass('active') ) {
      notification.addClass('tessla-error-notification-error').text(parseInt(notification.text()) + 1)
    }
  }

  onAddTeSSLaErrorText(text) {
    // get element
    var cons = $('#tessla-message-panel-body-wrapper > pre#tessla-error-output')

    // append new text to console
    cons.text(cons.text() + text + '\n')

    // scroll to bottom
    cons.scrollTop(cons.prop('scrollHeight'))

    // tab notification
    var notification = $('#tessla-message-panel-tabs > #tessla-error-output > span')

    if ( !notification.parent().hasClass('active') ) {
      notification.addClass('tessla-error-notification-error').text(parseInt(notification.text()) + 1)
    }
  }

  onAddWarningText(text) {
    // get element
    var cons = $('#tessla-message-panel-body-wrapper > pre#warning-output')

    // append new text to console
    cons.text(cons.text() + text + '\n')

    // scroll to bottom
    cons.scrollTop(cons.prop('scrollHeight'))

    // tab notification
    var notification = $('#tessla-message-panel-tabs > #warning-output > span')

    if ( !notification.parent().hasClass('active') ) {
      notification.addClass('tessla-error-notification-warning').text(parseInt(notification.text()) + 1)
    }
  }

  onAddLogText(text) {
    // get element
    var cons = $('#tessla-message-panel-body-wrapper > pre#workflow-output')

    // append new text to console
    cons.text(cons.text() + text + '\n')

    // scroll to bottom
    cons.scrollTop(cons.prop('scrollHeight'))

    // tab notification
    var notification = $('#tessla-message-panel-tabs > #workflow-output > span')

    if ( !notification.parent().hasClass('active') ) {
      notification.addClass('tessla-error-notification-workflow').text(parseInt(notification.text()) + 1)
    }
  }

  onClear() {
    $('#tessla-message-panel-body-wrapper > pre:visible').text('')
  }

  onHide() {
    this.$panel.animate({
      height: 'hide'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onShow() {
    this.$panel.animate({
      height: 'show'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onToggle() {
    this.$panel.animate({
      height: 'toggle'
    }, {
      duration: atom.config.get('tessla.animationSpeed'),
      queue: true
    })
  }

  onMouseDown(event) {
    // remember the mousedown position
    this.mousedown  = true
    this.mousedownY = event.pageY
    this.originalH  = $('#tessla-message-panel-body-wrapper > pre:visible').height()

    // prevent slowing atom down by propagating event through DOM and prevent
    // default event behavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseUp(event) {
    this.mousedown = false

    // set the height of the visible pre tag to all other pre tags
    var visiblePre = $('#tessla-message-panel-body-wrapper > pre:visible')
    var otherPres  = $('#tessla-message-panel-body-wrapper > pre')

    otherPres.height(visiblePre.height())

    // prevent slowing atom down by propagating event through DOM and prevent
    // default event behavior
    event.preventDefault()
    event.stopPropagation()
  }

  onMouseMove(event) {
    if (!this.mousedown) {
      return
    }

    // set new height
    $('#tessla-message-panel-body-wrapper > pre').height(
      this.originalH + this.mousedownY - event.pageY
    )

    // prevent slowing atom down by propagating event through DOM and prevent
    // default event behavior
    event.preventDefault()
    event.stopPropagation()
  }

  onSave() {
    // get content of open window
    var content = $('#tessla-message-panel-body-wrapper > pre:visible').text()

    // create a save dialog
    var app    = require('electron').remote;
    var dialog = app.dialog;
    var self   = this

    // show a save dialog
    dialog.showSaveDialog((filename) => {
      if (filename === undefined){
        // show warnings text in message panel
        self.onAddWarningText('You did not save the file')
      } else {

        // write file to disc
        require('fs').writeFile(filename, content, (err) => {

          // if there were errors show them
          if (err) {
            self.onAddWarningText('An error ocurred creating the file '+ err.message)
          }
        })
      }
    })
  }

  onChangeTab() {
    // remove notifications from this tab
    $(this).find('span')
      .removeClass('tessla-error-notification-success')
      .removeClass('tessla-error-notification-error')
      .removeClass('tessla-error-notification-warning')
      .removeClass('tessla-error-notification-workflow')
      .text('0')

    // get id of elements to show
    var showId = $(this).attr('id')
    $(this).addClass('active')
    $(this).siblings().removeClass('active')

    // next stage is getting the element with this id
    var pre = $('pre#' + showId)
    pre.show()
    pre.siblings().hide()

    // scroll to bottom
    pre.scrollTop(pre.prop("scrollHeight"))
  }

  destroy() {
    this.$panel.remove()
  }
}
