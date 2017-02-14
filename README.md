# TeSSLa-IDE package

This packages provides some IDE-like functions for C-Code and the temporal logic TeSSLa. There are two great GUI extensions the package provides.

## functions-sidebar

<img align="left" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/sidebar.png" width="175">

The functions sidebar is divided into two seperate areas. 

The upper area shows C functions that appear in the C files and C functions that are observed from within the TeSSLa sources of the current project. Each C file that can be found recursively in the current project directory is considered when fetching function singnatures. On the other hand only the first found TeSSLa source file is used by the IDE.

Both lists providing some special functions to the user. The cicled plus buttons inserting one line of TeSSLa code in the TeSSLa source file to observe the function calls in the compiled C binary. Next to the plus buttons there are _f(x)_ tags that can be colored in three different colors

When the the function tag is colored blue the function is not observed by the TeSSLa source code. When the function tag is colored green the function is observed by the TeSSLa source code. When the function tag is colored red the function is observed by the TeSSLa source code but not seem to exist in the considered C sources.

The rightmost text in each row indicates the position where the function was found in the C sources. The format is `filename(line:row)`, where the filename is the path to the file relative to the project root.

The lower area of the functions sidebar contains the formatted output from the TeSSLa server. The output is a list that contains each output identifier and the value that the identifier evaluates to at a certain time. Each output list is initially hidden and can be displayed by clicking the identifier. The border above the lower area contains a resize handle which can be used to change the space each area takes up.

## message-panel 

<img align="center" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/message-panel.png">
