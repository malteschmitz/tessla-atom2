# TeSSLa-IDE package

This packages provides some IDE-like functions for C-Code and the temporal logic TeSSLa. There are two great GUI extensions the package provides.

## functions-sidebar

<img align="left" src="https://github.com/dmlux/files/blob/master/images/TeSSLa/sidebar.png">

The functions sidebar is divided into areas. 

The upper area shows C functions that appear in the C files and C functions that are logged from inside the TeSSLa files of the current project. Each C file that can be found recursively in the current project directory is considered when fetching function names. On the other hand only the first found TeSSLa file is used by the IDE.

Both lists providing some special functions to the user. The cicled plus buttons inserting one line of TeSSLa code in the TeSSLa file to track the function calls of the C program. Next to the plus buttons there are _f(x)_ tags that can be coulored in three different colors
  
**blue**: The function is not tracked by the TeSSLa source code. **green**: The function is tracked by the TeSSLa source code. **red**: The function is tracked by the TeSSLa source code but not seem to exist in the considered C sources.
