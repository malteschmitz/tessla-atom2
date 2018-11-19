# TeSSLa-IDE Atom-package

<p align="left">
  <img src="https://img.shields.io/dub/l/vibe-d.svg" alt="License MIT">
  <img src="https://img.shields.io/badge/version-1.1.9-orange.svg" alt="Package version">
</p>

<p align="center">
  <img src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/screenshot.png?raw=true">
</p>

## Summary

The `tessla2-atom` package extends Atom by IDE features. The package contains C and TeSSLa linting as well as TeSSLa syntax highlighting and TeSSLa autocompletion for keywords, constants, types and standard library functions. The GUI is extended by a console consisting of compiler information, output view, error views, a linting view and a log view. Two sidebar docks providing information about generated traces and a list of all found C functions within the project. The sidebar view also provides test case generation for all found C functions. A toolbar for all actions and commands is also supported. To manage build targets and files that belong to those targets a `targets.yml` file is created in the project directory by the `tessla2-docker` package.

## Dependencies

The following dependencies are installed automatically by this package:
- [[Atom] tool-bar](https://atom.io/packages/tool-bar)
- [[Atom] Linter](https://atom.io/packages/linter)
- [[Atom] linter-gcc](https://atom.io/packages/linter-gcc)
- [[Atom] flexible-panels](https://atom.io/packages/flexible-panels)

The icons that are used in this package are provided by:
- [ionicons](http://ionicons.com)
- [Font Awesome](http://fontawesome.io)

## Sidebar

<img align="left" src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/sidebar.png?raw=true">

The sidebar is divided into two docks:

The "C Functions" dock contains all C functions that where found in the C files of the project. The considered C files are extracted from the `targets.yml` file. If the active target does not contain certain C source files the functions declared within these files will not be considered in the sidebar. Each function gets its own line within  the sidebar. The function elements in the sidebar are clickable and will open the file the functions were declared in and move the cursor the right spot. Additionally a plus button in front of each function allows the user to create a function call event in the TeSSLa specification mentioned in the `targets.yml`. In addition to the function name the concrete file as well as the line and column where the function appears in the file is placed on the right side of the line.

The "Output Streams" dock contains all outputs from the last performed action in a formatted way. All outputs are grouped by event name. Each event group contain all outputs as a list. The list entries contain the timestamp and the value. The list is ordered by the timestamp in such a way that the smallest timestamp is on top of the list and the biggest timestamp on the end. The lists are collapsed by default but can be expended by click. Buttons to collapse and expand all lists are on top of the dock.

## Message Panel

The message panel is located beneath the text editor and logs all information and messages that are shown to the user. The different types of messages are split up into several streams each with its own reiter. The user can select which reiter should be active. Only the contents of the active reiter are displayed in the the panel body. If there were any messages that belong to an other stream the little notification badge in front of the reiter name will be incremented and colored depending on which reiter was updated. Switching the active reiter will clear the notification. The counter will be reset and the color will be set back to the original color.

At the top of the message panel there is a resize handle which can be used to adjust the height of the panel and hence the amount of visible content in the active stream. On the top right there are three buttons. The buttons can be used to interact with the message panel.
- The X button closes the message panel.
- The garbage button clears the active content in the body of the message panel.
- the write button opens a save dialog to save the content of the active stream.

Each message belongs to at least one stream:
- The `Console` stream contains all messages that were returned by the compiled C sources and the messages returned by TeSSLaServer.
- The `Errors(C)` stream contains all messages returned by the clang compiler.
- The `Errors(TeSSLa)` stream contains all messages returned by the TeSSLa compiler.
- The `warnings` stream contains all messages that were displayed as notifications. The messages refer generally to wrong user input.
- The `Log` stream contains all comands that were used by the package and the responses to these comands.

<p align="center">
  <img src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/message-panel.png?raw=true">
</p>

## Tool Bar

<img align="right" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/tool-bar.png?raw=true">

To compile and run binaries compiled from source code the tool bar provides some buttons:

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/build-and-run-c.png?raw=true"> This button compiles all C files that can be found recursively in the current project directory and runs the resulting binary. Before the binary will be created it will create a build directory within the project directory. The binary will get the same name as the project but contains `_` instead of white spaces.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/build-c.png?raw=true"> This button will do nearly the same job but without executing the resulting binary.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/run-c.png?raw=true"> Whereas this button will only runs a binary which is located in the build directory and follows the naming conventions explained above.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/build-and-run-project.png?raw=true"> This button will trigger a few more steps than just compiling and running a binary file:

1. If the build directory in the project directory is not already created it will be created.
2. All C files in the current project directory are collected recursively and an Assembly file is compiled from them. The name format of the Assembly file is `<project-name>.bc`.
3. The Assembly code is patched by appending external symbols from the instrument functions library to each observed function. The file name format is `instrumented_<project-name>.bc`.
4. The patched Assembly file is compiled into an executable binary. The binary name format is `instrumented_<project-name>`
5. A `zlog.conf` file which is needed to format the output of the instrumented binary is created in the build directory.
6. The instrumented binary is executed which generates a trace file containing information about the function calls of the observed functions. Each line in this trace file is formatted by given rules in the `zlog.conf`. The name format of the trace file is `instrumented_<project-name>.trace`.  
7. The projected directory is scanned recursively to find a TeSSLa file. The first found TeSSLa file will be taken to compile it into a JSON file containing an AST (Abstract Syntax Tree).
8. At last the AST in the JSON file and trace file are given to the TeSSLaServer which will generate the output specified in the TeSSLa file.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/stop-process.png?raw=true"> This button will stop the process that is currently running. This process can be a compilation process or a running binary.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/toggle-message-panel.png?raw=true"> This button will toggle the message panel.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/toggle-functions-sidebar.png?raw=true"> This button will toggle the sidebar.

<img align="left" width="25" src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/set-up-split-view.png?raw=true"> This button will set up the split view. To set up the split view the active file should be within a project containing TeSSLa and C files. If there is no such file the split view can not be set up.

## Menu

<p align="center">
  <img src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/menu.png?raw=true">
</p>
In the "packages" menu there is a submenu of "TeSSLa" containing some actions for this package. For each menu entry the keymap binding which are fully listed and described in the keymap bindings section are shown on the right. The entries can also be found in the tool-bar on the right side of the workspace.


## Configuration

There are some settings that are important to set before you can use all features this packages provides:
- _Path to clang compiler_: This should be the path were the clang compiler is located on your system.

 **Note:** on MacOS/OS X the clang compiler installed by Xcode/Xcode command line tools does not have the LLVM extensions. To be able to use all features provided by this package you have to build clang by your self.

- _Path to instrument functions library_: This should be the path to the `libInstrumentFunctions.so`. Further information can be found [here](https://github.com/imdea-software/LLVM_Instrumentation_Pass).

- _Path to TeSSLa compiler_: This should be the path were the TeSSLa compiler is located on your system.

- _Path to TeSSLa server_: This should be the path were the TeSSLaServer is located on your system. The TeSSLaServer and further information about it can be found [here](https://github.com/imdea-software/TesslaServer)

- _zlog string format for variables_: This represents the format of how variables are formatted in the `.trace`-files.

 **Note:** The default value will work for the TeSSLaServer linked above. Changing this value may cause problems when the TeSSLaServer is trying to interprete the `.trace` file.

- _zlog string format for function calls_: This represents the format of how function calls are formatted in the `.trace`-files.

 **Note:** The default value will work for the TeSSLaServer linked above. Changing this value may cause problems when the TeSSLaServer is trying to interprete the `.trace` file.

- _Animation speed_: This value will set the speed of animations triggered in this package. The value represents a duration milliseconds
  
<p align="center">
  <img src="https://github.com/dmlux/TeSSLa/blob/master/screenshots/settings.png?raw=true">
</p>

## Keymap bindings

The TeSSLa package provides some keymap bindings to improve the work-flow. The following list contains all provided keymap bindings and their resulting effects.

| Keymap                            | Effect                            |
|:----------------------------------|:----------------------------------|
| `cmd-shift-t`                     | Toggles the package               |
| `cmd-b`                           | This keymap causes the package to build a binary compiled from C code that was found in the active project |
| `cmd-r`                           | This keymap causes the package to build and run a binary compiled from C code that was found in the active project |
| `cmd-t`                           | This keymap causes the package to pass step 1 to 8 from the [Tool Bar section](#tool-bar) |
| `ctrl-c`                          | This keymap causes the package to stop the process currently spawned and monitored by this package |
| `cmd-enter`                       | This keymap causes the package to set up the split view. Therefore all C files of the active project are put to the left side and all TeSSLa files are put the the right side. If no files are found a notification will be displayed |

## Supported Commands

There are some global commands other packages can trigger or subscribe to. A list of all global commands and their effects are shown in the table below.

| Command                           | Description                       |
|:----------------------------------|:----------------------------------|
| `tessla:toggle`                   | This command causes the package to toggle all components of the package including sidebar and message panel |
| `tessla:set-up-split-view`        | This command causes the package to set up the split view. Therefore all C files of the active project are put to the left side and all TeSSLa files are put the the right side. If no files are found a notification will be displayed |
| `tessla:toggle-sidebar`           | This command causes the package to toggle the sidebar |
| `tessla:toggle-message-panel`     | This command causes the package to toggle the message panel |
| `tessla:build-and-run-c-code`     | This command causes the package to build and run a binary compiled from C code that was found in the active project |
| `tessla:build-c-code`             | This command causes the package to build a binary compiled from C code that was found in the active project |
| `tessla:run-c-code`               | This command causes the package to run the binary `<project-name>` in `<project-directory>/build/` |
| `tessla:stop-current-process`     | This command causes the package to stop the process currently spawned and monitored by this package |
| `tessla:build-and-run-project`    | This command causes the package to pass step 1 to 8 from the [Tool Bar section](#tool-bar) |

## Authors

- [Denis-Michael Lux](https://www.github.com/dmlux/)<sup>(owner)</sup>
- Alexandra Lassota
- [Malte Schmitz](https://www.mlte.de)
