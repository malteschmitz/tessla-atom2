# TeSSLa2 Atom Package

<p align="left">
  <img src="https://img.shields.io/dub/l/vibe-d.svg" alt="License MIT">
  <img src="https://img.shields.io/badge/version-1.1.4-orange.svg" alt="Package version">
</p>

<p align="center">
  <img src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/screenshot.png?raw=true">
</p>

## Summary

The `tessla2-atom` package extends Atom by IDE features. The package contains C and TeSSLa linting as well as TeSSLa syntax highlighting and TeSSLa autocompletion for keywords, constants, types and standard library functions. The GUI is extended by a console consisting of compiler information, output view, error views, a linting view and a log view. Two sidebar docks providing information about generated traces and a list of all found C functions within the project. The sidebar view also provides test case generation for all found C functions. A toolbar for all actions and commands is also supported. To manage build targets and files that belong to those targets a `targets.yml` file is created in the project directory by the `tessla2-docker` package.

Implementation details for this package can be found [here](IMPLEMENTATION.md).

## Dependencies

The following dependencies are installed automatically by this package:
- [[Atom] tool-bar](https://atom.io/packages/tool-bar)
- [[Atom] Linter](https://atom.io/packages/linter)
- [[Atom] linter-gcc](https://atom.io/packages/linter-gcc)
- [[Atom] flexible-panels](https://atom.io/packages/flexible-panels)

The icons that are used in this package are provided by:
- [ionicons](http://ionicons.com)
- [Font Awesome](http://fontawesome.io)

## Sidebar Docks

<img align="left" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/sidebar.png?raw=true">

The sidebar is divided into two docks:

The "C Functions" dock contains all C functions that where found in the C files of the project. The considered C files are extracted from the `targets.yml` file. If the active target does not contain certain C source files the functions declared within these files will not be considered in the sidebar. Each function gets its own line within  the sidebar. The function elements in the sidebar are clickable and will open the file the functions were declared in and move the cursor the right spot. Additionally a plus button in front of each function allows the user to create a function call event in the TeSSLa specification mentioned in the `targets.yml`. In addition to the function name the concrete file as well as the line and column where the function appears in the file is placed on the right side of the line.

The "Output Streams" dock contains all outputs from the last performed action in a formatted way. All outputs are grouped by event name. Each event group contain all outputs as a list. The list entries contain the timestamp and the value. The list is ordered by the timestamp in such a way that the smallest timestamp is on top of the list and the biggest timestamp on the end. The lists are collapsed by default but can be expended by click. Buttons to collapse and expand all lists are on top of the dock.

## Console Dock

The console dock is located beneath the text editor and logs all information and messages that are shown to the user. The different types of messages are split up into several streams each with its own view. The user can switch between views by switching tabs in the console dock. The contents of the active stream can be cleared or saved to a user defined file by the two buttons in the top right corner of the view. It is also possible to filter the views contents by typing the search text into the input field.

Each message belongs to at least one stream:

The `Console` stream contains all messages that were returned by the compiled C sources and the messages returned by TeSSLa or TeSSLa_RV.

The `Errors(C)` stream contains all error messages returned by the clang compiler.

The `Errors(TeSSLa)` stream contains all error messages returned by TeSSLa and TeSSLa_RV.

The `warnings` stream contains all messages that were displayed as notifications. The messages refer generally to wrong user input.

The `Log` stream contains all comands that were used by the package and the responses to these comands.

<p align="center">
  <img src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/console.png?raw=true">
</p>

## Tool Bar

<img align="right" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/tool-bar.png?raw=true">

There are several actions that can be triggered by using the toolbar. All of those actions are also available via the `TeSSLa2` submenu of `Packages`. Each button will trigger an dedicated global command. Those commands can also be triggered by external packages or during developer palette. A full list of available commands can be found in the Menu section below. The following description shows each icon and the actions they are connected to:

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/create-trace.png?raw=true"> Creates a trace file (`.input`) from all C files that are mentioned in the active target from your projects `targets.yml` file.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/build-and-run-c.png?raw=true"> Compiles and executes all C files mentioned in the active target from your projects `targets.yml` file.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/build-and-run-project.png?raw=true"> Compiles and executes all C files mentioned in the active target from your projects `targets.yml` file. Subsequently the generated trace from the execution is verified by the TeSSLa specification also mentioned in the active target from your projects `targets.yml`.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/stop-process.png?raw=true"> This button will stop the process that is currently running. The button is disabled by default and will only be enabled if there is a process running.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/pull-latest-image.png?raw=true"> Triggers a docker pull request for the latest version of the `tessla2-docker` image. The image will be loaded and a corresponding container will be started afterwards. If there is a running during container startup it will be stopped and removed from container list.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/restart-container.png?raw=true"> The `tessla2-docker` container will be (re)started. If there is already a container with the same name running it will be stopped and removed and a new one will be started. Otherwise the container will just be started.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/set-up-split-view.png?raw=true"> All open text editors will be closed and the `.c` and `.input` files from the current project will be opened on the left split view while the `.tessla` files will be opened on the right split view.

<img align="left" width="34" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/restore-views.png?raw=true"> All view components will be checked wether they are still displayed. If one component is not available anymore it will be recreated and attached to the GUI.

## Menu

<p align="center">
  <img src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/menu.png?raw=true">
</p>
In the "packages" menu there is a submenu for "TeSSLa2" which contains package actions. For each menu entry the corresponding keymap bindings are shown if available. Most of the actions can also be found in the tool bar on the right side of the workspace.

## Keymap bindings

The TeSSLa package provides some keymap bindings to improve the work-flow. The following list contains all provided keymap bindings and their resulting effects.

| Keymap Linux & MacOS/Windows      | Effect                            |
|:----------------------------------|:----------------------------------|
| `cmd-shift-t`/`ctrl-shift-t`      | Toggle the package                |
| `cmd-shift-d`/`ctrl-shift-d`      | Deactivate the package            |
| `cmd-r`/`ctrl-r`                  | Build and run C sources           |
| `cmd-p`/`ctrl-p`                  | Create trace from C sources       |
| `cmd-t`/`ctrl-t`                  | Verify C sources by TeSSLa specification |
| `ctrl-c`/`ctrl-shift-c`           | Stop currently running process |
| `cmd-enter`/`ctrl-enter`          | Setup split view |

## Supported Commands

There are some global commands other packages can trigger or subscribe to. A list of all global commands and their effects are shown in the table below.

| Command                           | Description                       |
|:----------------------------------|:----------------------------------|
| `tessla2:activate`                | Activate the package. All views are created and the tessla2-docker container is started |
| `tessla2:deactivate`              | Deactivate the package. Remove all view components and stop the running tessla2-docker container |
| `tessla2:toggle`                  | Hide all view components and disable linting and autocompletion features |
| `tessla2:set-up-split-view`       | Close all text editors and create a split view where all `*.c` and `*.input` files are opened on the left side and all `.tessla` files are opened on the right side of the workspace. |
| `tessla2:reset-view`              | Check if all view components are still visible and reopen views if already closed |
| `tessla2:create-trace`            | Create a `.input` file from C sources found in `targets.yml`s active target |
| `tessla2:build-and-run-c-code`    | Build and run C sources form `targets.yml`s active target |
| `tessla2:verify-spec`             | Build and run C sources and verify resulting trace by TeSSLa specification mentioned in `targets.yml`s active target |
| `tessla2:stop-current-process`    | Stop running process |
| `tessla2:pull-image`              | Pull the latest version of the TeSSLa2 image from the registry and (re)start `tessla2-docker` container |
| `tessla2:start-container`         | (Re)start `tessla2-docker` container |

## Authors

- [Malte Schmitz](https://www.mlte.de)<sup>(owner)</sup>
- [Denis-Michael Lux](https://www.github.com/dmlux/)
- Alexandra Lassota
