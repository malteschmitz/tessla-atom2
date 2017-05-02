'use babel';

import path from 'path';
import fs from 'fs';

/**
 * A manager class for file parsing
 * @author Denis-Michael Lux <denis.lux@icloud.com>
 */
export default class TeSSLaFileManager {

  /**
   * Collects all C functions from the given file
   * @param {Object} config - Containing a source file and the path of the currently opened project
   * @return {string[]} An array containing the names of all found C functions
   */
  static collectCFunctionsFromSourceFile({ sourceFile, projectPath }) {
    // get function names
    const namesAssoc = {};
    const names = [];

    // get file extension
    const fileExtension = path.extname(sourceFile);
    const fileLines = fs.readFileSync(sourceFile).toString().split('\n');

    // if the source file is a C file
    if (fileExtension === '.c') {
      // create variables to get regex and matches
      const regex = /(?:[a-zA-Z][_\w]*)(?:\s*[*]?\s+|\s+[*]\s*)([a-zA-Z][_\w]*)\s*\(/g;
      let match = '';
      let lineCnt = 1;

      // loop over each line of code and get the match match
      fileLines.forEach((line) => {
        do {
          // get new match
          match = regex.exec(line);

          // if there where any match
          if (match) {
            // push match group 1 into names array
            const f = sourceFile.replace(`${projectPath}/`, '');
            const func = match[1];

            namesAssoc[`${f}:${func}`] = {
              fileName: f,
              functionName: func,
              occurrence: `${lineCnt}:${match.index}`,
            };
          }
        }
        // do this as long as there are any matches
        while (match);

        // increment line
        lineCnt += 1;
      });

      // copy elements back to names
      Object.keys(namesAssoc).forEach((funcObj) => {
        names.push(namesAssoc[funcObj]);
      });
    } else if (fileExtension === '.tessla') {  // if the file is a TeSSLa file
      fileLines.forEach((line) => {
        // first check if there is a function specified in this line
        const idxFnCall = line.indexOf('function_calls("');
        const idxComment = line.indexOf('--');

        // if there is a comment befor the function call skip this function call
        const onlyFunctionCall = idxFnCall !== -1 && idxComment === -1;
        const functionCallBeforeComment = idxFnCall !== -1 && idxComment !== -1
          && idxFnCall < idxComment;

        if (onlyFunctionCall || functionCallBeforeComment) {
          // extract function name
          let functionName = line.substr(idxFnCall + 'function_calls("'.length);
          functionName = functionName.substr(0, functionName.indexOf('"'));

          namesAssoc[functionName] = functionName;
        }
      });

      // copy elements back to names
      Object.keys(namesAssoc).forEach((funcObj) => {
        names.push(namesAssoc[funcObj]);
      });
    }

    // return function names as a array
    return names;
  }
}
