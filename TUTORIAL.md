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

| preferences | install `tessla2` | 
:-------------------------:|:-------------------------:
![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/preferences.png?raw=true)  |  ![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/install.png?raw=true)

The good news is that Atom provides a package market place out of the box. Everyone is able to publish own packages on Atom.io and ship updates for them. To get to the market place open Atom and navigate to the preferences pane. Choose the Install section and type in `tessla2`. A list of packages that hopefully contains the wanted one should appear. Press the install button on the `tessla2` package provided by `malteschmitz`. And that's it. The package gets installed automatically and will take care that the docker image gets installed on the system. The next section will provide instructions to get Docker running on your system.

### Docker and the TeSSLa-Docker-Image

Ok at this point everything seemed more than less self explanatory. We have already set up the IDE but not the tools that were used by the IDE. You might think: Why do we need Docker for using TeSSLa? We just have a collection of compilers and no special software that is supposed to be executed on a very special OS or an hard to set up environment. Well, the key component of the tool chain used by the TeSSLa-Atom-package is the clang with LLVM extensions. The standard clang does not offer these extensions in most cases. For example on MacOS the clang which is part of the command line tools does not support LLVM extensions. The only way to get a clang with LLVM extensions is to build it your self. It turned out that on some systems (especially on Windows) it is nearly impossible to get a working clang with LLVM extensions. The obvious solution for this problem is provided by Docker. Docker provides an environment to run software that is isolated in containers. A Docker container is a kind of lightweight virtual machine. In contrast to virtual machines containers do not bundle full operating systems but only libraries and settings required to make the software work. The key advantage of a Docker container is that it will run regardless on which OS it was started and on each environment it will provide the same functionality. As you might guess it is easy to build the clang with LLVM extensions on a Linux system as for example Ubuntu and isolate it into a Docker container providing an Ubuntu interface. In Addition to the clang compiler the container also contains the TeSSLa evaluation engine and TeSSLa RV script.


| Docker Community Edition | Download Docker CE | 
:-------------------------:|:-------------------------:
![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/docker-ce.png?raw=true)  |  ![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/download-docker.png?raw=true)

To be able to run the TeSSLa container we first need to install Docker itself. The safest way to get a working Docker software on your device is to use the official installer from Docker CE. On some systems Docker can be installed using the package manager but in some cases this will end up in a mess since some of the dependencies are not installed directly with the application itself. Anyway go the website linked above and scroll down to the section "Download Docker Community Edition". Choose your OS and download the installer. After the download is done just double click it and install it. If there were no problems the Docker deamon should run in the background now. Now you are able to run Docker containers.


| Docker Running | Load TeSSLa Image | 
:-------------------------:|:-------------------------:
![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/docker-running.png?raw=true)  |  ![](https://github.com/malteschmitz/tessla2-atom/blob/master/screenshots/load-tessla-image.png?raw=true)

The next step is getting the TeSSLa container. So how do we get this TeSSLa container? There are two ways to get the container. First you can pull the latest version of the TeSSLa image using the atom package. The tool bar provides buttons to trigger those events. On package activation the latest version of the image is pulled and the corresponding container started any way. The other way to pull the image hosted on [rv.isp.uni-luebeck.de](http://rv.isp.uni-luebeck.de/tessla/tessla-docker.zip) and start the container is by using the following commands:

```
docker rmi registry.mlte.de/isp/tessla-docker  
docker load -i registry.mlte.de/isp/tessla-docker  
```

The first command removes other images named 'registry.mlte.de/isp/tessla-docker' that had already been loaded. The second one will load the TeSSLa image so Docker is able to run this image inside of a container. To execute the second command it is important to navigate to the directory that contains the TeSSLa image. When you execute the command in the listing above make sure you are in the directory the TeSSLa image is located in. Now the IDE is able to start a container and execute all commands. If there were no problems so far you are done with setup. All components that are needed are installed and ready to use. The next step is to try it out.

### An example application

In this section we will create an example C application and a TeSSLa specification to check if the application meets the specification. Before we start writing code we have to set up a project directory. Open Atom if it is not open yet and go to File – Add Project Folder…. Choose a directory where the new project should be located and press OK.

Now lets add some source files to the newly created project directory. Therefore you can add a new file by right click on the directory in the tree view on the left side of Atom or by using the file menu. We will first create a new C file named sub_add.c. Now put the following content into the C file:

```C
int add(int x, int y) {
  return x+y;
}

int sub(int x, int y) {
  return x-y;
}

int main() {
  int sum = 0;
  for (int i = 0; i &lt; 5; i++) {
    sum = add(sum, sub(i,2));
  }
  sum = add(sum, add(21,21));
  for (int i = 0; i &lt; 5; i++) {
    sum = add(sum, sub(i,2));
  }
}
```

Lets try to understand what the code is actually doing. The first function obviously calculates the sum of two given integers x and y while the second function is calculating the difference between two given integers x and y. The main function is just a starting point for the actual algorithm that uses the two functions defined before. The algorithm just defines a sum variable that will hold a value which is modified by the following two for loops. The for loops are just invoking the add and sub methods. We do not need to discuss about the intellectual value of this code since it is just some code that can easily be tested against a specification. OK, the C application is ready to use. Time to create a specification for our code…

The files containing TeSSLa specifications are files having the `.tessla` extension. Such a file is currently missing in our project so create a new file called `spec.tessla.` Enter the following lines of code for the specification:

```Ruby
include "/usr/local/opt/tessla_rv/streams.tessla"
include "stdlib.tessla"

define add_event : Events := function_calls("add")
define sub_event : Events := function_calls("sub")

define add_count := eventCount(add_event)
define sub_count := eventCount(sub_event)
define diff := sub(add_count, sub_count)

define error := geq(diff, literal(2))

out diff
out error
```

Lets figure out what this specification describes. The first two lines are defining events occurring in the execution of our program. The events we are looking for are function calls as you might guess when you are looking to the right side of the assignment. The first event represents the add function calls and the second event represents the sub function calls. After that we define two variables each of them contains a number representing how often the respective functions were called. Then we just form the difference between both values to get a comparison value. The last line containing a define checks if the difference of both function call counters is greater or equal two. The last two lines defining outputs for the values of diff and error. In other words: the specification says there have to be at least 2 more add calls then sub calls.