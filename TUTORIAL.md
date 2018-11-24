# TeSSLa 2017

The Temporal Stream-Based Specification Language (short TeSSLa) was developed in the scope of the CONIRAS project as a specification language. In the CONIRAS project the goal was to use runtime verification techniques early in the development process for debugging multicore systems. Because synthesizing a monitor on an FPGA can take a huge amount of time, it was an important requirement that the elements of a monitor on the FPGA do not have to be synthesized every time a new monitor is created. Instead, a general bunch of elements should be synthesized on the FPGA and only if the elements needed for a TeSSLa specification and their connections do not match to the ones available on the FPGA, a new synthesis process has to be started.

Because the input data for a TeSSLa monitor is supposed to the output of a multicore system, the input is modelled in the form of asynchronous streams. Besides the standard temporal logic operators, TeSSLa contains many other operators like arithmetic ones, timing operators for specifying real-time properties and stream manipulation operations to allow a precise specification of the output streams derived from the input streams.

## Tools

  * [Online Simulator](http://rv.isp.uni-luebeck.de/tessla/): The online simulator provides a visualization of TeSSLa input and output streams, which are automatically updated when you change the specification or the input.
  * [Docker Image](http://rv.isp.uni-luebeck.de/tessla/tessla-docker.zip): Docker image with Compiler, Engine and TeSSLa RV script.
  * [TeSSLa2 Package](https://atom.io/packages/tessla2): We integrated all the tools mentioned above into a package for the Atom text editor.
  
## TeSSLa 2 Atom Package

The following tutorial demonstrates how to use the plugin. In this tutorial we will describe the whole set up process for the TeSSLa Atom package and finally give an example of how to use TeSSLa. Before we are starting with the set up tutorial we will first take a look at TeSSLa, Atom and all other components that are needed to get an environment for developing C programs and TeSSLa specifications.

### Introduction

TeSSLa allows users to write formal specifications of program properties that are checked during or after execution of the program. In this tutorial we are using the software instrumentation, so the actual source code that should be checked has to be modified for this purpose. All information that are gathered during execution are based on timestamps. Therefore the observed C functions have to be modified to print logging information to stdout. The logs are stored in a special format as a trace file which is needed by the TeSSLa evaluation engine as well as the compiled TeSSLa specification to check if the program meets the specification. The TeSSLa specification gets compiled by the TeSSLa compiler.

As you might see in this brief process description there are some components that are essential to be able to use TeSSLa. Now that we have a rough understanding of how the main components are working together we will start with installing all needed components.

Atom is a text editor that is based on the Electron framework and hence web based. Technically the Atom Editor is a web browser that is encapsulated into a native executable app/program. All add-ons that are developed to increase the range of functions provided by Atom are written in web based programming languages like JavaScript or CoffeeScript and designed in HTML and CSS. As you can imagine it is pretty easy to develop new Atom packages with a good web development background.

<p align="center">
  <img src="https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/screenshot.png?raw=true">
</p>

Now lets start with installation stuff. First you have to [download](https://atom.io/download/mac) the latest version of Atom. Therefore visit [Atom.io](https://atom.io). Directly on the main page there is a 'download' button that will start a download of Atom suitable for the OS you are working on. The actual application is packed into a zip archive. So just unzip the archive with a tool of your choice. When you are working on MacOS you should move the unpacked application to your local applications directory.

Now that we have installed Atom we are taking care of the TeSSLa package. The TeSSLa package adds IDE like functions to Atom allowing developers to use all tools like the TeSSLa compiler, clang and the TeSSLa evaluation engine from within Atom. For a developer it is a more comfortable way to verify C code using TeSSLa since all the different tools and commands do not have to be used manually. There are also some helping components that are added to the GUI. For Example a console like component that displays the C programs output and all commands that were executed by the TeSSLa package as well as the responses to these commands. So how do we get this package properly installed on our system?

:-------------------------:|:-------------------------:
![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/preferences.png?raw=true)  |  ![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/install.png?raw=true)

The good news is that Atom provides a package market place out of the box. Everyone is able to publish own packages on Atom.io and ship updates for them. To get to the market place open Atom and navigate to the preferences pane. Choose the Install section and type in `tessla2`. A list of packages that hopefully contains the wanted one should appear. Press the install button on the `tessla2` package provided by `malteschmitz`. And that's it. The package gets installed automatically and will take care that the docker image gets installed on the system. The next section will provide instructions to get Docker running on your system.

### Docker and the TeSSLa-Docker-Image

Ok at this point everything seemed more than less self explanatory. We have already set up the IDE but not the tools that were used by the IDE. You might think: Why do we need Docker for using TeSSLa? We just have a collection of compilers and no special software that is supposed to be executed on a very special OS or an hard to set up environment. Well, the key component of the tool chain used by the TeSSLa-Atom-package is the clang with LLVM extensions. The standard clang does not offer these extensions in most cases. For example on MacOS the clang which is part of the command line tools does not support LLVM extensions. The only way to get a clang with LLVM extensions is to build it your self. It turned out that on some systems (especially on Windows) it is nearly impossible to get a working clang with LLVM extensions. The obvious solution for this problem is provided by Docker. Docker provides an environment to run software that is isolated in containers. A Docker container is a kind of lightweight virtual machine. In contrast to virtual machines containers do not bundle full operating systems but only libraries and settings required to make the software work. The key advantage of a Docker container is that it will run regardless on which OS it was started and on each environment it will provide the same functionality. As you might guess it is easy to build the clang with LLVM extensions on a Linux system as for example Ubuntu and isolate it into a Docker container providing an Ubuntu interface. In Addition to the clang compiler the container also contains the TeSSLa evaluation engine and TeSSLa RV script.


:-------------------------:|:-------------------------:
![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/docker-ce.png?raw=true)  |  ![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/download-docker.png?raw=true)