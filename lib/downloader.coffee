request = require 'request'
progress = require 'request-progress'
fs = require 'fs'
path = require 'path'
os = require 'os'
DecompressZip = require 'decompress-zip'
childProcess = require 'child_process'
onFinished = require 'on-finished'

module.exports=
  class Downloader

    @download: ({ url, filePath, callback }) ->
      notification = atom.notifications.addInfo "Downloading TeSSLa Docker image",
        detail: "The TeSSLa Docker image which is nessesary to compile and run TeSSLa specifications will be downloaded."
        dismissable: yes

      btnWrapper = document.createElement "div"
      btnWrapper.classList.add "btn-toolbar"

      startButton = document.createElement "a"
      startButton.innerHTML = "Download"
      startButton.classList.add "btn", "btn-info"
      startButton.addEventListener "click", ->
        fs.stat path.dirname(filePath), (err, stats) =>
          if err?.code is 'ENOENT'
            fs.mkdir path.dirname(filePath), =>
              notification.dismiss()
              @downloadAndLoad { url, filePath, callback }

      stopButton = document.createElement "a"
      stopButton.innerHTML = "No thanks"
      stopButton.classList.add "btn", "btn-info"
      stopButton.addEventListener "click", ->
        notification.dismiss()

      btnWrapper.appendChild startButton
      btnWrapper.appendChild stopButton

      # get the notification to include missing stuff
      try
        notificationView = atom.views.getView notification
        notificationContent = notificationView.element.querySelector '.detail-content'
        notificationContent?.appendChild btnWrapper
      catch _


    @downloadAndSetup: ({ url, filePath, callback }) ->
      progressNotification = atom.notifications.addInfo "Download progress #{path.basename url}",
        detail: "Download #{path.basename url} to #{path.dirname filePath}"
        dismissable: yes

      progressWrapper = document.createElement "div"
      progressWrapper.classList.add "block"

      progressBar = document.createElement "progress"
      progressBar.classList.add "inline-block"
      progressBar.max = "100"
      progressBar.value = "0"

      progressTime = document.createElement "span"
      progressTime.classList.add "inline-block"
      progressTime.innerHTML = 'At 0%'

      progressWrapper.appendChild progressBar
      progressWrapper.appendChild progressTime

      abortWrapper = document.createElement "div"
      abortWrapper.classList.add "btn-toolbar"

      abortBtn = document.createElement "a"
      abortBtn.classList.add "btn", "btn-info"
      abortBtn.innerHTML = 'Cancel'

      abortWrapper.appendChild abortBtn

      try
        progressNotificationView = atom.views.getView progressNotification
        progressNotificationContent = progressNotificationView.element.querySelector ".detail-content"
        progressNotificationContent?.appendChild progressWrapper
        progressNotificationContent?.appendChild abortWrapper

      catch _

      req = null
      progress(req = request url).on "progress", (state) =>
        progressBar.value = "$#{Math.round(state.percent * 100)}"
        progressTime.innerHTML = "Download at #{Math.round(state.percent * 100)}%, remaining time: #{Math.round(state.time.remaining)}s"
      .on 'end', () =>
        progressNotification.dismiss()

        onFinished req, (err, res) =>
          return if res?._aborted or err?

          unzipNotification = atom.notifications.addInfo "Unzip and Load #{path.basename(url)}",
            detail: "Unzipping and loading tessla image. This process may take about 1-2 minutes."
            dismissable: yes

          indeterminateProgressWrapper = document.createElement "div"
          indeterminateProgressWrapper.classList.add "block"
          indeterminateProgressWrapper.appendChild document.createElement "progress"

          try
            unzipNotificationView = atom.views.getView unzipNotification
            unzipNotificationContent = unzipNotificationView.element.querySelector ".detail-content"
            unzipNotificationContent?.appendChild indeterminateProgressWrapper
          catch _

          atom.config.set('tessla2.alreadySetUpDockerContainer', true);

          unzipper = new DecompressZip filePath
          unzipper.on "error", err =>
            unzipNotification.dismiss();

          unzipper.on "extract", log =>
            childProcess.spawn("docker", ["rmi", "tessla"]).on "close", =>
              load = childProcess.spawn "docker", ["load", "-i", path.join path.dirname(filePath), 'tessla']

              load.on "close", =>
                dockerArgs = ["run", "--volume", "#{path.join os.homedir(), ".tessla-env"}:/tessla", "-w", "/tessla", "-tid", "--name", "tessla", "tessla", "sh"]
                childProcess.spawn "docker", dockerArgs
                unzipNotification.dismiss()

          unzipper.extract
            path: path.dirname filePath
            filter: (file) => return yes

        callback()
      .pipe fs.createWriteStream filePath

      abortBtn.addEventListener "click", =>
        req.abort()
