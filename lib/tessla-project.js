'use babel'

import path from 'path'
import fileSystem from 'fs'
import childProcess from 'child_process'
import scanFolder from 'scan-folder'

let sfConfig = {
  dotfolder: false, // no hidden folders
  dotfiles: false,  // no hidden files
  modules: false    // no module contents
}

export default class TeSSLaProject {

  constructor(projPath) {
    this.projPath   = ''
    this.outputDir  = ''
    this.binName    = ''

    // set fallback values if there are no arguments given
    if (typeof projPath !== 'undefined') {
      this.projPath   = projPath
      this.updateOutputDir()
      this.updateBinName()
    }

    // files
    this.cFiles       = this.getCFiles()
    this.tesslaFiles  = this.getTeSSLaFiles()
  }

  setProjPath(projPath) {
    // set values for current project
    this.projPath     = projPath
    this.updateOutputDir()
    this.updateBinName()

    // collect files from project
    this.cFiles       = this.getCFiles()
    this.tesslaFiles  = this.getTeSSLaFiles()
  }

  updateOutputDir() {
    this.outputDir = path.join(this.projPath, 'build')
  }

  updateBinName() {
    this.binName = path.basename(this.projPath).replace(' ', '_')
  }

  getCFiles() {
    var files = scanFolder(this.projPath, ".c", true, sfConfig)

    // set array to null if there were no matches
    if (files.length == 0) {
      files = null
    }

    return files
  }

  getTeSSLaFiles() {
    var files = scanFolder(this.projPath, ".tessla", true, sfConfig)

    // set array to null if there were no matches
    if (files.length == 0) {
      files = null
    }

    return files
  }

  setUpProjectStructure() {
    //onsole.log('TeSSLaProject.setUpProjectStructure()')
    // check if linter file already exists if yes were done here
    if (!fileSystem.existsSync(path.join(this.projPath, '.gcc-flags.json'))) {
      // spawn process
      var which = childProcess.spawn('which', ['clang'], {
        cwd:   this.projPath,
        shell: true
      })

      // buffer out stream into data array
      var clangPath
      which.stdout.on('data', (line) => {
        // store path
        clangPath = line.toString()
      })

      // look into data array
      which.on('close', (code) => {
        // if there is a compiler available on the system then add a linter file
        if (clangPath.length > 0) {
          // remove line breaks
          clangPath = clangPath.replace(/\r?\n|\r/g, '')

          // create file with given content
          var fileContent = ''

          fileContent += '{\n'
          fileContent += '\t"execPath": "' + clangPath + '",\n'
          fileContent += '\t"gccDefaultCFlags": "-Wall -c -fsyntax-only",\n'
          fileContent += '\t"gccIncludePaths": ".,./include,./path",\n'
          fileContent += '\t"gccSuppressWarnings": false\n'
          fileContent += '}'

          // write content into file
          fileSystem.writeFileSync(path.join(this.projPath, '.gcc-flags.json'), fileContent)
        }
      })
    }
  }

  clear() {
    this.projPath   = ''
    this.outputDir  = ''
    this.binName    = ''
  }
}
