# TeSSLa-IDE package

<p align="left">
  <img src="https://img.shields.io/dub/l/vibe-d.svg" alt="License MIT">
  <img src="https://img.shields.io/badge/version-1.1.0-orange.svg" alt="Package version">
</p>

<p align="center">
  <img src="https://github.com/dmlux/files/blob/master/images/TeSSLa/screenshot.png">
</p>

## Overview
- [Introduction](#introduction)
- [Dependencies](#dependencies)
- [Functions Sidebar](#functions-sidebar)
- [Message Panel](#message-panel)
- [Tool Bar](#tool-bar)
- [Configuration](#configuration)
- [Supported Commands](#supported-commands)
- [Authors](#authors)

## Introduction

This packages provides some IDE-like functions for C-Code and the TeSSLa LTL. There are two great GUI extensions that the package provides. In Addition to the GUI components there is also a grammar file for the TeSSLa LTL provided to enable syntax highlighting for files having the `.tessla` extension. Make sure to disable other packages providing syntax highlighting for `.tessla` files to get the correct source code visualization.

## Dependencies

To use the full range of functions that are provided by this package some dependencies are needed:
- [InstrumentFunctions library](https://github.com/imdea-software/LLVM_Instrumentation_Pass)
- [TeSSLaServer](https://github.com/imdea-software/TesslaServer)
  
The following dependencies are installed automatically by this package:
- [[Atom] tool-bar](https://atom.io/packages/tool-bar)
- [[Atom] Linter](https://atom.io/packages/linter)
- [[Atom] linter-gcc](https://atom.io/packages/linter-gcc)
  
The icons that are used in this package are provided by:
- [ionicons](http://ionicons.com)
- [Font Awesome](http://fontawesome.io)
  

**Note:** The correct paths to the compilers and the TeSSLaServer as well as the external libraries that are listed above should be set first. The correct paths can be set in the settings pane of this package. To get to the settings pane open `Preferences > Packages > tessla > settings`. If there are missing paths some functions in some circumstances can not be used. Each value has a default fallback which is in some cases the correct path.

## Functions Sidebar

<img align="left" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/sidebar.png">

The functions sidebar is divided into two seperate areas. Each border inside this panel works as a resize handle which is also indicated by the changing cursor appearance. 

The upper area shows C functions that appear in the C files and C functions that are observed from within the TeSSLa sources of the current project. Each C file that can be found recursively in the current project directory is considered when fetching function singnatures. On the other hand only the first found TeSSLa source file is used by the IDE.

Both lists providing some special functions to the user. The circled plus buttons inserting one line of TeSSLa code in the TeSSLa source file to observe the function calls in the compiled C binary. Next to the plus buttons there are _f(x)_ tags that can be colored in three different colors

When the the function tag is colored blue the function is not observed by the TeSSLa source code. When the function tag is colored green the function is observed by the TeSSLa source code and when the function tag is colored red the function is observed by the TeSSLa source code but does not seem to exist in the considered C sources.

The rightmost text in each row indicates the position where the function was found in the C sources. The format is `filename(line:row)`, where the filename is the path to the file relative to the project root.

The lower area of the functions sidebar contains the formatted output from the TeSSLaServer. The output is a list that contains each output identifier and the value that the identifier evaluates to at a certain time. Each output list is initially hidden and can be displayed by clicking the identifier. The entries within the list are displayed in two columns. The left column shows the time when the identifier evaluates to the value in the right column. The time format is `HH:MM:SS.mmm`. 

The border above the lower area contains a resize handle which can be used to change the space each area takes up. The whole sidebar can be resized as well as both areas inside of it. On the left edge there is a resize handle to adjust the width. The sidebar has a minimum width and a maximum width that can not be exceeded. 

## Message Panel 

The message panel is located beneath the text editor and logs all information and messages that are shown to the user. The different types of messages are split up into several streams each with its own reiter. The user can select which reiter should be active. Only the contents of the active reiter are displayed in the the panel body. If there were any messages that belong to an other stream the little notification badge in front of the reiter name will be incremented and colored depending on which reiter was updated. Switching the active reiter will clear the notification. The counter will be reset and the color will be set back to the original color.

At the top of the message panel there is a resize handle which can be used to adjust the height of the panel and hence the amount of visible content in the active stream. On the top right there are three buttons. The buttons can be used to interact with the message panel. 
- The X button closes the message panel.
- The garbage button clears the active content in the body of the message panel.
- the write button opens a save dialog to save the content of the active stream. 

Each message belongs to at least one stream:
- The `Console` stream contains all messages that were returned from compiled C sources and the messages returned by TeSSLaServer.
- The `Errors(C)` stream contains all messages returned by the clang compiler.
- The `Errors(TeSSLa)` stream contains all messages returned by the TeSSLa compiler.
- The `warnings` stream contains all messages that were displayed as notifications. The messages refer generally to wrong user input.
- The `Log` stream contains all comands that were used by the package and the responses to these comands.
  
<img align="center" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/message-panel.png">

## Tool Bar

<img align="right" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/tool-bar.png">

To compile and run binaries compiled from source code the tool bar provides some buttons:

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/build-and-run-c.png"> This button compiles all C files that can be found recursively in the current project directory and runs the resulting binary. Before the binary will be created it will create a build directory within the project directory. The binary will get the same name as the project but contains `_` instead of white spaces.

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/build-c.png"> This button will do nearly the same job but without executing the resulting binary.

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/run-c.png"> Whereas this button will only runs a binary which is located in the build directory and follows the naming conventions explained above.

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/build-and-run-project.png"> This button will trigger a few more steps than just compiling and running a binary file:

1. If the build directory in the project directory is not already created it will be created.
2. All C files in the current project directory are collected recursively and an Assembly file is compiled from them. The name format of the Assembly file is `<project-name>.bc`.
3. The Assembly code is patched by appending external symbols from the instrument functions library to each observed function. The file name format is `instrumented_<project-name>.bc`. 
4. The patched Assembly file is compiled into an executable binary. The binary name format is `instrumented_<project-name>`
5. A `zlog.conf` file which is needed to format the output of the instrumented binary is created in the build directory.
6. The instrumented binary is executed which generates a trace file containing information about the function calls of the observed functions. Each line in this trace file is formatted by given rules in the `zlog.conf`. The name format of the trace file is `instrumented_<project-name>.trace`.  
7. The projected directory is scanned recursively to find a TeSSLa file. The first found TeSSLa file will be taken to compile it into a JSON file containing an AST (Abstract Syntax Tree).
8. At last the AST in the JSON file and trace file are given to the TeSSLaServer which will generate the output specified in the TeSSLa file.
  
<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/stop-process.png"> This button will stop the process that is currently running. This process can be a compilation process or a running binary.

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/toggle-message-panel.png"> This button will toggle the message panel.

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/toggle-functions-sidebar.png"> This button will toggle the functions sidebar.

<img align="left" width="25" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/set-up-split-view.png"> This button will set up the split view. To set up the split view the active file should be within a project containing TeSSLa and C files. If there is no such file the split view can not be set up.

## Configuration

There are some settings that are important to set before you can use all features this packages provides:
- _Path to clang compiler_: This should be the path were the clang compiler is located on your system. 

  **Note:** on MacOS/OS X the clang compiler installed by Xcode/Xcode command line tools does not have the LLVM extensions. To be able to use all features provided by this package you have to build clang by your self. 

- _Path to instrument functions library_: This should be the path to the `libInstrumentFunctions.so`. Further information can be found [here](https://github.com/imdea-software/LLVM_Instrumentation_Pass).

- _Path to TeSSLa compiler_: This should be the path were the TeSSLa compiler is located on your system. 

- _Path to TeSSLa server_: This should be the path were the TeSSLaServer is located on your system. The TeSSLaServer and further information about it can be found [here](https://github.com/imdea-software/TesslaServer)

- _Zlog string formatting for variables_: This represents the format of how variables are formatted in the `.trace`-files. 

  **Note:** The default value will work for the TeSSLaServer linked above. Changing this value may cause problems when the TeSSLaServer is trying to interprete the `.trace` file.
  
- _Zlog string formatting for function calls_: This represents the format of how function calls are formatted in the `.trace`-files.

  **Note:** The default value will work for the TeSSLaServer linked above. Changing this value may cause problems when the TeSSLaServer is trying to interprete the `.trace` file.
  
- _Animation speed for toggling menus and panels in milliseconds_: This value will adjust the speed of animations triggered in this package. The value represents milliseconds
  
<p align="center">
  <img src="https://github.com/dmlux/files/blob/master/images/TeSSLa/settings.png">
</p>

## Supported Commands

There are some global commands other packages can subscribe to:

| Command                           | Description                       |
|:----------------------------------|:----------------------------------|
| `tessla:toggle`                   | This command causes the package to toggle all components of the package including sidebar and message panel | 
| `tessla:set-up-split-view`        | This command causes the package to set up the split view. Therefore all C files of the active project are put to the left side and all TeSSLa files are put the the right side. If no files are found a notification will be displayed | 
| `tessla:toggle-functions-sidebar` | This command causes the package to toggle the functions sidebar |
| `tessla:toggle-message-panel`     | This command causes the package to toggle the message panel |
| `tessla:build-and-run-c-code`     | This command causes the package to build and run a binary compiled from C code that was found in the active project |
| `tessla:build-c-code`             | This command causes the package to build a binary compiled from C code that was found in the active project |
| `tessla:run-c-code`               | This command causes the package to run the binary `<project-name>` in `<project-directory>/build/` |
| `tessla:stop-current-process`     | This command causes the package to stop the process currently spawned and monitored by this package |
| `tessla:build-and-run-project`    | This command causes the package to run step 1 to 8 from the [Tool Bar section](#tool-bar) |
| `tessla:toggle-functions-sidebar` | This command causes the package to toggle the functions sidebar |

## Authors

- [Denis-Michael Lux](https://www.github.com/dmlux/)<sup>(owner)</sup>
- Alexandra Lassota
