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
