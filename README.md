# TeSSLa-IDE package

![MIT Licence](https://badges.frapsoft.com/os/mit/mit.svg?v=103)

## Introduction

This packages provides some IDE-like functions for C-Code and the TeSSLa LTL. There are two great GUI extensions that the package provides. In Addition to the GUI components there is also a grammar file for the TeSSLa LTL provided to enable syntax highlighting for files having the `.tessla` extension. Make sure to disable other packages providing syntax highlighting for `.tessla` files to get the correct source code visualization.

## Dependencies

To use the full range of functions that are provided by this package some dependencies are needed:
  - [InstrumentFunctions library](https://github.com/imdea-software/LLVM_Instrumentation_Pass)
  - [TeSSLaServer](https://github.com/imdea-software/TesslaServer)
  

**Note:** The correct paths to the compilers and the TeSSLaServer as well as the external libraries that are listed above should be set first. The correct paths can be set in the settings pane of this package. To get to the settings pane open `Preferences > Packages > tessla > settings`. If there are missing paths some functions in some circumstances can not be used. Each value has a default fallback which is in some cases the correct path.

## functions-sidebar

<img align="left" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/sidebar.png">

The functions sidebar is divided into two seperate areas. Each border inside this panel works as a resize handle which is also indicated by the changing cursor appearance. 

The upper area shows C functions that appear in the C files and C functions that are observed from within the TeSSLa sources of the current project. Each C file that can be found recursively in the current project directory is considered when fetching function singnatures. On the other hand only the first found TeSSLa source file is used by the IDE.

Both lists providing some special functions to the user. The circled plus buttons inserting one line of TeSSLa code in the TeSSLa source file to observe the function calls in the compiled C binary. Next to the plus buttons there are _f(x)_ tags that can be colored in three different colors

When the the function tag is colored blue the function is not observed by the TeSSLa source code. When the function tag is colored green the function is observed by the TeSSLa source code and when the function tag is colored red the function is observed by the TeSSLa source code but does not seem to exist in the considered C sources.

The rightmost text in each row indicates the position where the function was found in the C sources. The format is `filename(line:row)`, where the filename is the path to the file relative to the project root.

The lower area of the functions sidebar contains the formatted output from the TeSSLaServer. The output is a list that contains each output identifier and the value that the identifier evaluates to at a certain time. Each output list is initially hidden and can be displayed by clicking the identifier. The entries within the list are displayed in two columns. The left column shows the time when the identifier evaluates to the value in the right column. The time format is `HH:MM:SS.mmm`. 

The border above the lower area contains a resize handle which can be used to change the space each area takes up. The whole sidebar can be resized as well as both areas inside of it. On the left edge there is a resize handle to adjust the width. The sidebar has a minimum width and a maximum width that can not be exceeded. 

## message-panel 

The message panel is located beneath the text editor and logs all information and messages that are shown to the user. The different types of messages are split up to several streams each with its own reiter. The user can select which reiter should be active. Only the contents of the active reiter are displayed in the the panel body. If there were any messages that belong to an other stream the little notification badge in front of the reiter name will be incremented and colored depending on which reiter was updated. Switching the active reiter will clear the notification. The counter will be reset and the color will be set back to the original color.

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
