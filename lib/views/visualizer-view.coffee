
{ VISUALIZER } = require "../utils/constants"
{ visualizer } = require "tessla-visualizer"

module.exports=
  class VisualizerView

    constructor: (@config) ->
      @title = @config.title
      @URI = @config.URI
      @viewManager = null

      @element = document.createElement "div"
      @element.classList.add "visualizer-wrapper"

      #<h1>TeSSLa Visualizer Test and Example</h1>
      #<label for="pan"><input type="radio" name="panbrush" id="pan" checked="checked" value="pan"> pan</label>
      #<label for="brush"><input type="radio" name="panbrush" id="brush" value="brush"> brush</label>
      #<svg id="visualizer-container" style="width:100%;height:800px;"></svg>

      elementHeadline = document.createElement "h1"
      elementHeadline.innerHTML = "TeSSLa Visualizer Test and Example"

      panInput = document.createElement "input"
      panInput.type = "radio"
      panInput.name = "panbrush"
      panInput.id = "pan"
      panInput.checked = "checked"
      panInput.value = "pan"

      panLabel = document.createElement "label"
      panLabel.setAttribute "for", "pan"
      panLabel.innerHTML = panInput.outerHTML + " pan"

      brushInput = document.createElement "input"
      brushInput.type = "radio"
      brushInput.name = "panbrush"
      brushInput.id = "brush"
      brushInput.value = "brush"

      brushLabel = document.createElement "label"
      brushLabel.setAttribute "for", "brush"
      brushLabel.innerHTML = brushInput.outerHTML + " brush"

      SVGContainer = document.createElement "svg"
      SVGContainer.id = "visualizer-container"

      @element.appendChild elementHeadline
      @element.appendChild panLabel
      @element.appendChild brushLabel
      @element.appendChild SVGContainer



    setViewManager: (viewManager) ->
      @viewManager = viewManager

    getTitle: ->
      @title

    getURI: ->
      @URI

    getDefaultLocation: ->
      "center"

    getAllowedLocations: ->
      ["center", "bottom"]

    destroy: ->
      @element.remove()

    display: ->
      options =
        axis: true,
        signalHeight: 20,
        eventHeight: 14,
        draggerRadius: 10,
        strokeColor: "#0000ff",
        fillColor: "#ccccff",
        maxZoom: 40,
        labelWidth: 100,
        streams: [
          {
            name: "hans",
            style: "dots",
            data: [{time: 5, value: 6}, {time: 10, value: 10}, {time: 17, value: 20}, {time: 21, value: 7}, {time: 29.7, value: 5}],
            editable: true
          },
          {
            name: "franz",
            style: "plot",
            data: [{time: 5, value: 6}, {time: 10, value: 10}, {time: 17, value: 20}, {time: 21, value: 7}, {time: 29.7, value: 5}],
            editable: true
          },
          {
            name: "fritz",
            style: "signal",
            data: [{time: 0, value: 6}, {time: .1, value: 10}, {time: 17, value: 20}, {time: 21, value: 7}, {time: 22, value: 17}],
            editable: true
          },
          {
            name: "emil",
            style: "events",
            data: [{time: 0, value: 6}, {time: .1, value: 10}, {time: 17, value: 20}, {time: 21, value: 7}, {time: 22, value: 17}],
            editable: true
          }
        ]

      visu = visualizer "#visualizer-container", options

      setTimeout(() =>
        document.getElementById("visualizer-container").style = "height: 300px;";
      , 2000);
