request = require "request"
progress = require "request-progress"
fs = require "fs"
path = require "path"
os = require "os"
DecompressZip = require "decompress-zip"
childProcess = require "child_process"
onFinished = require "on-finished"
Docker = require "dockerode"
docker = new Docker

{TESSLA_REGISTRY} = require "./constants"

module.exports=
  class Downloader

    @dockerDownload: ({ callback }) ->
      # show notification to user that a pull request will start that may take
      # a few minutes if the latest version of tessla2 is not already downloaded
      notification = atom.notifications.addInfo "Downloading/Updating TeSSLa2 Docker image",
        detail: "The TeSSLa2 Docker image which is nessesary for TeSSLa2 will be updated or downloaded. This may take a few minutes of time, so please be patient."
        dismissable: yes

      downloadProgressWrapper = document.createElement "div"
      downloadProgressWrapper.classList.add "block"

      downloadProgress = document.createElement "progress"
      downloadProgress.classList.add "block", "full-width-progress"

      downloadProgressTime = document.createElement "span"
      downloadProgressTime.classList.add "block"
      downloadProgressTime.innerHTML = "Download: waiting"

      downloadProgressWrapper.appendChild downloadProgress
      downloadProgressWrapper.appendChild downloadProgressTime

      extractingProgressWrapper = document.createElement "div"
      extractingProgressWrapper.classList.add "block"

      extractingProgress = document.createElement "progress"
      extractingProgress.classList.add "block", "full-width-progress"

      extractingProgressTime = document.createElement "span"
      extractingProgressTime.classList.add "block"
      extractingProgressTime.innerHTML = "Extraction: waiting"

      extractingProgressWrapper.appendChild extractingProgress
      extractingProgressWrapper.appendChild extractingProgressTime

      try
        notificationView = atom.views.getView notification
        notificationViewContent = notificationView.element.querySelector ".detail-content"
        notificationViewContent?.appendChild downloadProgressWrapper
        notificationViewContent?.appendChild extractingProgressWrapper
      catch _

      # pull the latest version of tessla2 from the ISP repository
      docker.pull TESSLA_REGISTRY, (err, stream) =>
        messageChannelByID = {}
        downloads = {}
        extractions = {}

        onFinished = (err, output) =>
          # console.log "Docker pull is completed"
          notification.dismiss()
          callback messageChannelByID

        onProgress = (event) ->
          # do not log progress stuff to console since this will be done via the
          # notification
          if event.status isnt "Downloading" and event.status isnt "Extracting"
            if event.id?
              messageChannelByID[event.id] = [] unless event.id of messageChannelByID
              if event.id is "latest"
                messageChannelByID[event.id].push { type: "entry", label: "Docker", msg: "#{event.id} #{event.status}" }
              else
                messageChannelByID[event.id].push "#{event.status}"

            else
              messageChannelByID.unidentified = [] unless "unidentified" of messageChannelByID
              messageChannelByID.unidentified.push { type: "entry", label: "Docker", msg: "#{event.status}" }

          # in the other case we will take care of updating the progress information
          else
            if event.id? and event.progressDetail?
              # store download progess
              if event.status is "Downloading"
                # store current information
                downloads[event.id] =
                  current: event.progressDetail.current
                  total: event.progressDetail.total

              #store extracting progress
              if event.status is "Extracting"
                # store current information
                extractions[event.id] =
                  current: event.progressDetail.current
                  total: event.progressDetail.total

          # now update the progress bar
          valueDownloads = 0
          valueExtractions = 0
          maxDownloads = 1
          maxExtractions = 1

          for id, state of downloads
            valueDownloads += state.current
            maxDownloads += state.total

          for id, state of extractions
            valueExtractions += state.current
            maxExtractions += state.total

          downloadProgress.value = valueDownloads
          extractingProgress.value = valueExtractions
          downloadProgress.max = maxDownloads
          extractingProgress.max = maxExtractions

          downloadCurrentMB = parseFloat((Math.round(valueDownloads)/10000)/100).toFixed(2)
          downloadMaxMB = parseFloat((Math.round(maxDownloads)/10000)/100).toFixed(2)
          downloadPercentage = Math.round(valueDownloads/maxDownloads * 100)

          extractingCurrentMB = parseFloat((Math.round(valueExtractions)/10000)/100).toFixed(2)
          extractingMaxMB = parseFloat((Math.round(maxExtractions)/10000)/100).toFixed(2)
          extractingPercentage = Math.round(valueExtractions/maxExtractions * 100)

          downloadProgressTime.innerHTML = "Download: waiting"
          downloadProgressTime.innerHTML = "Download: #{downloadCurrentMB}MB/#{downloadMaxMB}MB (#{downloadPercentage}%)" if downloadPercentage isnt 0
          downloadProgressTime.innerHTML = "Download: complete" if downloadPercentage is 100


          extractingProgressTime.innerHTML = "Extraction: waiting"
          extractingProgressTime.innerHTML = "Extraction: #{extractingCurrentMB}MB/#{extractingMaxMB}MB (#{extractingPercentage}%)" if extractingPercentage isnt 0
          extractingProgressTime.innerHTML = "Extraction: complete" if extractingPercentage is 100

        # attach progress listener to pull request
        docker.modem.followProgress stream, onFinished, onProgress
