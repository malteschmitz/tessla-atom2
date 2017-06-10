## 1.4.0 (June 10, 2017)
Features:
  - Added Atom Dock support
  - Added automatic Download for the TeSSLa image. The Image is loaded when this plugin is started the first time.
    If the download was already done a boolean flag in the settings will be set. To get asked for download on the
    next restart the checkbox in the settings pane has to be uncheck before restart.
  - Added a bunch of additional bugs..... uuuhm features...

## 1.3.0 (April 28, 2017)
Bug-fixes:
  - Fixed a bug that causes the Package to not show the syntax error markers in the text-editors

Features:
  - The package now only supports Docker.
  - The Docker container is set up only once and then reused for each command
  - Improved the message panel. Each entry is now highlightable and a timestamp in front of each entry is added.
  - Each Log entry has a label that is colored to get a better overview of what happend for each command.

## 1.2.1 (March 21, 2017)
Bug-fixes:
  - Fixed [#1](https://github.com/malteschmitz/tessla-atom/issues/1)

## 1.2.0 (March 10, 2017)
Features:
  - Added support for a docker image containing all the necessary command line tools.
  - Improved cross-platform functionality. Works now on Windows machines, too.

## 1.1.6 (March 14, 2017)
Bug-fixes:
  - Untitled tabs do not force Atom to crash anymore. Closes [#1](https://github.com/dmlux/TeSSLa/issues/1)

## 1.1.5 (March 2, 2017)
Bug-fixes:
  - Fixed an error that occurred when running 'compile and run project'. The package will throw an error when trying to remove a zlog.conf file that is not existing before the first compilation.
  - Improved resizing the sections inside the sidebar. Sometimes the lower area of the sidebar is not fully scrollable.

## 1.1.4 (February 23, 2017)
Features:
  - Added keymap-bindings support. A full list of keymap-bindings is available in the `Packages > TeSSLa` submenu
  - Added a row counter to the formatted output list in the sidebar

Bug-fixes:
  - Renamed the emitter event 'distribute-unsued-functions' to 'distribute-unused-functions'
  - Fixed an error that occurred when deleting the content of the build directory and running the project after that. Then the `zlog.conf` file was not created again and the compilation process terminated with an error
  - Fixed an error that occurred when patching the Assembly file. The `opt` command had no prefix containing the path to the `opt` binary. In some casees this caused an `could not find opt` error
  - Fixed an error that occurred when deactivating the package. The sidebar and message-panel where not removed from workspace
  - Fixed an error that occurred when toggling the package. The tool-bar sometimes showed inverted toggle behavior compared to the other components
  - Changed cusor in the formatted output list in the sidebar to default cursor when hovering over the rows of the sublists
  - Changed the relative links in the `README.md` file to absolute links so the images are displayed on the `atom.io` package-site
  - Removed the `overview`-section from the `README.md` since the anchor-links are getting broken in the `atom.io` package-site

## 1.1.3 (February 17, 2017)
Features:
  - Changed internal class names
  - Updated README.md

Bug-fixes:
  - changed the appearance of values that were initially set (timestamp = 0) to 'init'
  - Fixed an error that occurred when running an existing C binary

## 1.1.2 (February 15, 2017)
Features:
  - Updated the description string in the packages.json.

Bug-fixes:
  - Changed the images in the README.md to point to the raw images

## 1.1.1 (February 15, 2017)
Features:
  - Added README.md to package

## 1.1.0 (February 14, 2017)
Features:
  - Added a table like view to offer a formatted TeSSLa server output

Bug-fixes:
  - Fixed some smaller problems

## 1.0.0 (February 09, 2017)
Features:
  - Added functions sidebar to workspace
  - Added message panel to workspace
  - Added TeSSLa syntax highlighting
  - Added tool bar to build and run C code and TeSSLa code
