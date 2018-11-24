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