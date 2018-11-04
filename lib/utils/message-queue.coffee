module.exports=
  class MessageQueue

    constructor: (@viewManager) ->
      @memory = []

    enqueueEntry: (entry) ->
      @memory.push entry

    enqueueEntries: (entries) ->
      @memory = @memory.concat entries

    enqueueListEntry: (entry) ->
      @memory.push entry

    flush: ->
      # if view manager is not set up then we can not flush!
      if not @viewManager?
        console.log "[TeSSLa2][error] message-queue.coffee:16: Can not flush because of undefined view manager."
        return

      # if the several views are not set up we can not flush!
      if not @viewManager.views?
        console.log "[TeSSLa2][error] message-queue.coffee:21: Views of view manager are not build up."
        return

      # if log view is not set up we can not flush!
      if not @viewManager.views.logView?
        console.log "[TeSSLa2][error] message-queue.coffee:26: Can not flush because log view is not build up."
        return

      for queueObj in @memory
        # skip undefined queue objects
        if (not "type" of queueObj) or (not "title" of queueObj) or (not "label" of queueObj) or (not "msg" of queueObj)
          console.log "[TeSSLa2][error] message-queue.coffee:32: Enqueued object does not represent a message!.", queueObj
          continue

        # filter different message types
        switch queueObj.type
          when "entry"
            @viewManager.views.logView.addEntry [queueObj.label, queueObj.msg]
          when "listEntry"
            @viewManager.views.logView.addListEntry queueObj.title, [queueObj.label, queueObj.msg]
          else
            console.log "[TeSSLa2][error] message-queue.coffee:41: Undefined message type detected."

        # clear queue content
        @memory = []
