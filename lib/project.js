'use babel';

/* global atom */

import path from 'path';
import fileSystem from 'fs';
import childProcess from 'child_process';
import scanFolder from 'scan-folder';

/**
 * A class representing a project in the workspace
 * @author Denis-Michael Lux <denis.lux@icloud.com>
 */
export default class Project {

  sfConfig: {
    dotfolder: false, // no hidden folders
    dotfiles: false,  // no hidden files
    modules: false    // no module contents
  };

  /**
   * Constructs a new project object.
   * @constructor
   * @param {string} projPath - The path of the currently used project
   */
  constructor(projPath) {
    this.projPath = '';
    this.outputDir = '';
    this.binName = '';

    // set fallback values if there are no arguments given
    if (typeof projPath !== 'undefined') {
      this.projPath = projPath;
      this.updateOutputDir();
      this.updateBinName();
    }

    // files
    this.cFiles = this.getCFiles();
    this.tesslaFiles = this.getTeSSLaFiles();
  }

  /**
   * Connects a new project directory to this object.
   * @param {string} projPath - The path to the new project
   * @return {void}
   */
  setProjPath(projPath) {
    // set values for current project
    this.projPath = projPath;
    this.updateOutputDir();
    this.updateBinName();

    // collect files from project
    this.cFiles = this.getCFiles();
    this.tesslaFiles = this.getTeSSLaFiles();
  }

  /**
   * Updates the output dir Path based on the other variables
   * @return {void}
   */
  updateOutputDir() {
    this.outputDir = path.join(this.projPath, 'build');
  }

  /**
   * Updates the binary name based on the other variables
   * @return {void}
   */
  updateBinName() {
    this.binName = path.basename(this.projPath).replace(' ', '_');
  }

  /**
   * Collects all C files from the current project.
   * @return {string[]} An array containing all C file from the directory
   */
  getCFiles() {
    console.log("Changed Project " + this.projPath);

    // collect files
    let files = scanFolder(this.projPath, '.c', true, this.sfConfig);

    // set array to null if there were no matches
    if (files.length === 0) {
      files = null;
    }

    return files;
  }

  /**
   * Collects all TeSSLa files from the current project.
   * @return {string[]} An array containing all TeSSLa files from the directory
   */
  getTeSSLaFiles() {
    let files = scanFolder(this.projPath, '.tessla', true, this.sfConfig);

    // set array to null if there were no matches
    if (files.length === 0) {
      files = null;
    }

    return files;
  }

  /**
   * Creates the linter file in the current project
   * @return {void}
   */
  setUpProjectStructure() {
    // console.log('TeSSLaProject.setUpProjectStructure()')
    // check if linter file already exists if yes were done here
    if (!fileSystem.existsSync(path.join(this.projPath, '.gcc-flags.json'))) {
      // spawn process
      const which = childProcess.spawn('which', ['clang'], {
        cwd: this.projPath,
        shell: true,
      });

      // buffer out stream into data array
      let clangPath;
      which.stdout.on('data', (line) => {
        // store path
        clangPath = line.toString();
      });

      // look into data array
      which.on('close', () => {
        // if there is a compiler available on the system then add a linter file
        if (clangPath.length > 0) {
          // remove line breaks
          clangPath = clangPath.replace(/\r?\n|\r/g, '');

          // create file with given content
          let fileContent = '';

          fileContent += '{\n';
          fileContent += `\t"execPath": "${clangPath}",\n`;
          fileContent += '\t"gccDefaultCFlags": "-Wall -c -fsyntax-only",\n';
          fileContent += '\t"gccIncludePaths": ".,./include,./path",\n';
          fileContent += '\t"gccSuppressWarnings": false\n';
          fileContent += '}';

          // write content into file
          fileSystem.writeFileSync(path.join(this.projPath, '.gcc-flags.json'), fileContent);
        }
      });
    }
  }

  /**
   * Resets all properties
   * @return {void}
   */
  clear() {
    this.projPath = '';
    this.outputDir = '';
    this.binName = '';
  }
}
