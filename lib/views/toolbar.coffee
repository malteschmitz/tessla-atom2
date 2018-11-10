
module.exports=
  createToolbar: (toolBar) ->
    toolBarButtons = {}
    toolBarButtons.CreateTrace = toolBar.addButton({
      icon: "code-download"
      callback: "tessla2:create-trace"
      tooltip: "Create trace from C sources"
      iconset: "ion"
    })
    toolBarButtons.BuildAndRunCCode = toolBar.addButton({
      icon: "play-circle"
      callback: "tessla2:build-and-run-c-code"
      tooltip: "Build and run C sources"
      iconset: "fa"
    })
    toolBarButtons.BuildAndRunProject = toolBar.addButton({
      icon: "ios-circle-filled"
      callback: "tessla2:verify-spec"
      tooltip: "Verify by TeSSLa specification"
      iconset: "ion"
    })
    toolBar.addSpacer()
    toolBarButtons.Stop = toolBar.addButton({
      icon: "android-checkbox-blank"
      callback: "tessla2:stop-current-process"
      tooltip: "Stop current process"
      iconset: "ion"
    })
    toolBarButtons.Stop.setEnabled(no)
    toolBar.addSpacer()
    toolBar.addButton({
      icon: "columns"
      callback: "tessla2:set-up-split-view"
      tooltip: "Set up split view"
      iconset: "fa"
    })
    toolBar.addButton({
      icon: "window-maximize"
      callback: "tessla2:reset-view"
      tooltip: "Restore Views"
      iconset: "fa"
    })
    atom.config.set("tool-bar.iconSize", "16px")
    atom.config.set("tool-bar.position", "Right")
    atom.config.set("tool-bar.visible", yes)
    return toolBarButtons
