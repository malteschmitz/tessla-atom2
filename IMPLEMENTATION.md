# Implementation Details

The implementation is split apart into several components which are responsible for certain tasks. The whole implementation is located in `lib` and has the subdirectories `autocomplete`, `controllers`, `linter`, `utils` and `views`. In the following all the contents of those subdirectories are explained in detail as well as their responsibilities.

## package.json

As in every one project the package.json contains detailed information about the package, the authors, dependencies, in which repository the source files can be found and so on. The following list contains the most important key within this file:

  * `name`: Represents the name of the package. If you want to install packages via `atom.io/packages` or using the internal atom install view which can be found in preferences you have to type in the name that is specified in this property to find the package.
  * `main`: This key tells atom where to find the file that is responsible for the housekeeping of this package.
  * `description`: The text which is displayed in the atom internal installer after searching packages view keywords. The name and this short description is shown to the user.
  * `keywords`: The keywords which are considered during search on `atom.io` or in the internal installer
  * `activationCommands`: These commands tell docker which exact global command should be triggered if the package gets activated. The listener to this command can be attached or changed within the main file mentioned in the `main` key.
  * `repository`: Tells Atom where to finde the actual repository. This key is very important for atoms built-in package manager `apm`. If you plan to publish patches or newer versions of this software this key should be valid since `apm` tries to set the version number. Also the Atom installer fetches the package including all its files from this repository.
  * `dependencies`: Contains a list of Node.js dependencies for this project.
  * `consumedServices`: These are services provided by other packages that `tessla2` needs to work properly. Examples for such services are the toolbar and flexible panels.
  * `providedServices`: In contrast to consumed services these services are provided to other packages. A service in this context is just a function with their own context that can be passed to other packages. Examples for such services are Linter and Autocompleter. The base linter and Autocomplete+ are using these services exchange information between them and `tessla2`.
  * `package-deps`: A list of Atom package dependencies.
  
## tessla.coffee

The `tessla.coffee` file is responsible for the packages housekeeping. It manages everything that happens before, on and during activation. All services that are consumed by this package are also specified within this file:

  * `initialize`: Sets values to components like the controller and makes sure that everything that is needed by the consumed services as well the package it self is in place and predefined.
  * `activate`: The activation method manages the installation of atom package dependencies. Once the installation is done the Docker stuff is checked and started. If Docker and alle created view components are ready to work the split view is set up and everything is in place to start.
  * `deactivate`: Shuts the package down and removes all view components from the workspace. Also makes sure that global commands getting unbound to prevent exhaustive use of listeners.
  * `toggle`: hides and shows package components and functionalities.
  * `consumeFlexiblePanels`: Gets a manager object to create all console view elements. The attributes and behavior of those views is also specified in here.
  * `consumeToolBar`: Gets a manager object to set up the toolbar for this package.
  * `provideLinter`: Passes back a `TeSSLaLinter` object to the base linter.
  * `provideAutocomplete`: Passes back a `TeSSLaAutocompleter` object to Autocomplete+
  
## lib/autcomplete

All files within this directory are responsible for autocompletion within text editors. Currently it contains only a single file that defines the `TeSSLaAutocompleter` object. The Autocomplete+ package is a core package of atom and provides an infrastructure for custom autocompleters. A package can extend or replace the standard autocompleter in different contexts. See [Autocomplete+](https://github.com/atom/autocomplete-plus) for further information about the package.

The `TeSSLaAutocompleter` has some properties that are used by Autocomplete+ to decide in which context it should use the suggestions provided by `TeSSLaAutocompleter`. The section _Defining A Provider_ in the [documentation](https://github.com/atom/autocomplete-plus/wiki/Provider-API#defining%20a%20provide) explaines all properties and their effects in detailed.

The starting point for the autocompleter ist the `getSuggestions` method. It gets an object of options from Autocomplete+. The most important ones are `options.editor` which contains the actual [TextEditor](https://atom.io/docs/api/v1.2.1/TextEditor) and the `options.prefix` that contains the word the user just types in. Both are used to filter the relevant suggestions from the included files and the list of keywords, types and constants. The includes from the file the user is currently working in are resolved and contents of these files are considered for suggestions. If one of those files also contains includes those includes are ignored to make IO operations to read those files more efficient. To extract symbols like variables and functions from the included files the string with the file contents is parsed by regular expressions. For detailed information about the exact information see [TeSSLaAutocompleter](https://github.com/malteschmitz/tessla2-atom/blob/master/lib/autocomplete/tessla-autocompleter.coffee)

To decrease the number of fired autocompletion event events are only executed if at least 100 milliseconds are spent between calls.

## lib/linter

All files within this directory are responsible for linting sources files of a given type. In our case the interesting file type is `.tessla` which contains tessla specifications. Therefore the `TeSSLaLinter` object has properties to specify on which file types it should be used and which action triggers linting. The most important part of the `TeSSLaLinter` object is the `onLint` function that describes what happens when linting is triggered.

The linter first determines which files triggered the linting action. Afterwards the concrete file is passed to the TeSSLa compiler within the docker container. Since each project is mounted in its dedicated container the compiler can easily access the file and can compile it. To prevent a full compilation process the compiler is used in `--verify-only` mode which does not produce any output except errors and warnings. The full linting process is currently a little expensive due to the fact that the TeSSLa compiler is written and executed as Java byte and hence needs to start up a JVM.

## lib/controllers

The controllers directory contains classes that are responsible to process user interaction and global commands. Most of the source code in here translates the global compilation commands into build scripts using the docker container. The only file in here is `controller.coffee` and handles exactly the described events. Actions that are performed in the `Controller` class are:

  * lock and unlock buttons in the tool bar
  * make sure a project is active
  * make sure targets in the project are valid
  * create trace file from project directory
  * build and run C code from the project directory
  * build C code and verify it by using the tessla specification from the project directory
  * save all text editors before compiling anything
  * trigger Docker image pull request or container startup
  * set up split view and restore view elements
  * stop running process if user triggers corresponding event
  
## lib/utils

The utility classes and functions are support functions to solve repeatingly arising problems. Files that are located in this direcory are

  * `constants.coffee`: The constants file contains a collection of constant values like the name for the Docker container that contains the TeSSLa tools. Important constants like the registry address the actual name of the TeSSLa Docker image, if the package runs in dev mode and the URIs for the custom view components are stored in this file.
  * `docker-mediator.coffee`: The `DockerMediator` is responsible for pulling the newest version of the image and the lifecycle of the TeSSLa Docker image.
  * `file-reader.coffee`: The `FileReader` extracts C functions from C source files to enable visualization of these in the sidebar views.
  * `logger.coffee`: The `Logger` class is a wrapper for `console.log` which uses the `debug` constant of `constants.coffee`. Is `debug` set to `yes` the logging will happen as expected otherwise the logging will be suppressed. This will suppress console pollution in production mode.
  * `project.coffee`: The `Project` class represents a project directory. It will make sure that files like the `.gcc-flags.json` and `targets.yml` file are available. It also provides the contents of the `targets.yml` as well as the active target within this file.
  * `utils.coffee`: Contains utility functions like checking if an object is set or if an object is of type function etc.
  
## lib/views

The `lib/views` directory contains custom view elements. All view elements are dock views which means they have to satisfy a certain interface. Futher information about the interface and the behavior of docks can be found [here](http://blog.atom.io/2017/05/23/docks-deep-dive.html) and as mention in this article [here](https://flight-manual.atom.io/hacking-atom/sections/package-active-editor-info/). The view classes are:

  * `sidebar-view.coffee`: The `SidebarView` is the sidebar view which shows C functions found in the C sources of the project. It uses the `FileReader` from `lib/utils` to find those C functions.
  * `sidebar-view-element.coffe`: The `SidebarViewElement` represents the entries in the list of `SidebarView`
  * `output-view.coffee`: The `OutputView` shows a formatted version of the the `tessla` output in the side dock.
  * `output-view-element.coffee`: The `OutputViewElement` represents a list entry in the `OutputView`.