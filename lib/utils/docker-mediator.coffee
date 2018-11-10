docker = new require("dockerode")()
childProcess = require("child_process")
fs = require("fs")
path = require("path")

{TESSLA_CONTAINER_NAME, TESSLA_IMAGE_NAME, TESSLA_REGISTRY} = require("./constants")
{isSet, isFunction} = require("./utils")
Logger = require("./logger")

class DockerDaemonNotRunningError
  constructor: (@title, @message) ->
    if not isSet(@title)
      @title = "Docker Deamon is not running"
    if not isSet(@message)
      @message = "The Docker deamon does not respond. Please make sure to start the Docker daemon before using Containers."

class InvalidContainerRootError
  constructor: (@title, @message) ->
    if not isSet(@title)
      @title = "Invalid container root directory"
    if not isSet(@message)
      @message = "The root directory for the TeSSLa Docker container is invalid."


class DockerMediator
  constructor: ->

  isDockerDaemonRunning: =>
    return new Promise((resolve, reject) =>
      Logger.log("DockerMediator.isDockerDaemonRunning()")
      docker.info().then((resolved) =>
        resolve()
      ).catch((rejected) =>
        Logger.err("DockerMediator.isDockerDaemonRunning(): ", reject)
        reject(new DockerDaemonNotRunningError)
      )
    )

  pull: =>
    return new Promise((resolve, reject) =>
      Logger.log("DockerMediator.pull()")
      messages = []
      messages.push({ type: "entry", label: "Docker", msg: "docker pull #{TESSLA_REGISTRY}" })
      @isDockerDaemonRunning()
      .then(=> @pullTeSSLaImage())
      .then((output) =>
        for id, msgs of output
          if id is "latest" or id is "unidentified"
            messages = messages.concat(msgs)
          else if msgs.length > 1
            messages.push({ type: "listEntry", label: "Docker", title: id, msg: msgs })
          else
            messages.push({ type: "entry", label: "Docker", title: "", msg: msgs[0] })
        resolve(messages)
      )
      .catch((err) =>
        Logger.err(err instanceof DockerDaemonNotRunningError)
        reject(err)
      )
    )

  startTeSSLaContainer: (rootDir) ->
    return new Promise((resolve, reject) =>
      Logger.log("DockerMediator.startTeSSLaContainer()")
      if not fs.existsSync(rootDir)
        reject(new InvalidContainerRootError())
      if not fs.lstatSync(rootDir).isDirectory()
        reject(new InvlaidContainerRootError())
      logs = []

      stop = childProcess.spawn("docker", ["rm", "-f", "#{TESSLA_CONTAINER_NAME}"])
      stop.on("close", (code) =>
        if code is 0
          logs.push(["Docker", "docker rm -f #{TESSLA_CONTAINER_NAME}"])
        dockerArgs = [
          "run",                            # starting a container from an existing image
          "--volume", "#{rootDir}:/tessla", # mounting the container to root
          "-w", "/tessla",                  # setting the working directory (`cd /tessla` inside the container)
          "-tid",                           # allocate a pseudo-TTY keep STDIN open even if not attached and tun container in background (-t -i -d -> `docker run -- help`)
          "--name", TESSLA_CONTAINER_NAME,  # name of the container will be the argument
          TESSLA_IMAGE_NAME,                # specifies the name of the image
          "sh"                              # executes the shell inside the container to prevent stopping the container imediatly
        ]

        start = childProcess.spawn("docker", dockerArgs)
        start.stderr.on("data", (err) => Logger.err(err.toString()))
        start.on("close", (code) =>
          logs.push(["Docker", "docker #{dockerArgs.join(" ")}"])
          if code is 0
            resolve(logs)
        )
      )
    )


  isTeSSLaContainerRunning: ->
    return new Promise((resolve, reject) =>
      Logger.log("DockerMediator.isDockerContainerRunning()")
      # get container ID. If the container is not running there will be no ID
      # returned by the process
      containerID = childProcess.execSync("docker ps -q -f name=#{TESSLA_CONTAINER_NAME}").toString()
      # if the container exists just call the callback. If not make the container
      # running
      if containerID isnt ""
        # call the if yes callback function
        resolve(yes)
      else
        # if the there was no ID the container is not running so call the ifNot
        # callback
        resolve(no)
    )

  pullTeSSLaImage: ->
    return new Promise((resolve, reject) =>
      # show notification to user that a pull request will start that may take
      # a few minutes if the latest version of tessla2 is not already downloaded
      Logger.log("DockerMediator.isDockerDaemonRunning()")
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
      docker.pull(TESSLA_REGISTRY, (err, stream) =>
        messageChannelByID = {}
        downloads = {}
        extractions = {}

        onFinished = (err, output) =>
          # console.log "Docker pull is completed"
          notification.dismiss()
          resolve(messageChannelByID)

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
        docker.modem.followProgress(stream, onFinished, onProgress)
      )
    )

module.exports= {
  DockerDaemonNotRunningError: DockerDaemonNotRunningError
  DockerMediator: DockerMediator
}
