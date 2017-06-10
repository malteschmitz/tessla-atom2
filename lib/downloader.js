'use babel';

/* global atom */

import request from 'request';
import progress from 'request-progress';
import fs from 'fs';
import path from 'path';
import os from 'os';
import DecompressZip from 'decompress-zip';
import childProcess from 'child_process';
import onFinished from 'on-finished';

export default class Downloader {

  /**
   * Downloads a file from the given url
   * @param {string} url - The URL the file gets downloaded from
   * @param {string} fileURL - The file that should be created
   * @param {function} callback - A callback function that will be invoked after download was
   * finished
   * @return {void}
   */
  static download({ url, filePath, callback }) {
    // build dialog
    const notification = atom.notifications.addInfo('Downloading TeSSLa Docker image', {
      detail: 'The TeSSLa Docker which is nessesary to compile and run TeSSLa specifications image will be downloaded.',
      dismissable: true,
    });

    const start = () => {
      // close notification
      notification.dismiss();

      // create progress
      const progressNotification = atom.notifications.addInfo(`Download progress ${path.basename(url)}`, {
        detail: `Download ${path.basename(url)} to ${path.dirname(filePath)}`,
        dismissable: true,
      });

      // create a progress bar
      const progressWrapper = document.createElement('div');
      progressWrapper.classList.add('block');

      const progressBar = document.createElement('progress');
      progressBar.classList.add('inline-block');
      progressBar.max = "100";
      progressBar.value = "0";

      const progressTime = document.createElement('span');
      progressTime.classList.add('inline-block');
      progressTime.innerHTML = 'At 0%';

      progressWrapper.appendChild(progressBar);
      progressWrapper.appendChild(progressTime);

      // create the abort button
      const abortWrapper = document.createElement('div');
      abortWrapper.classList.add('btn-toolbar');

      const abortBtn = document.createElement('a');
      abortBtn.classList.add('btn', 'btn-info');
      abortBtn.innerHTML = 'Cancel';

      abortWrapper.appendChild(abortBtn);

      try {
        const progressNotificationView = atom.views.getView(progressNotification).element;
        const progressNotificationContent = progressNotificationView.querySelector('.detail-content');

        if (progressNotificationContent) {
          progressNotificationContent.appendChild(progressWrapper);
          progressNotificationContent.appendChild(abortWrapper);
        }
      } catch(_) { /* not empty now */ }

      // remember request
      let req;

      // create a http request
      progress(req = request(url)).on('progress', (state) => {
        // update view components
        progressBar.value = `${Math.round(state.percent * 100)}`;
        progressTime.innerHTML = `Download at ${Math.round(state.percent * 100)}%, remaining time: ${Math.round(state.time.remaining)}s`;
      }).on('end', () => {
        // close notification
        progressNotification.dismiss();

        // if file is
        onFinished(req, (err, res) => {
          // console.log(err, res);
          // if the request was aborted stop continuing
          if (res && res._aborted) {
            console.log("aborted download so don't extract");
            return;
          }

          // if an error occurred also stop
          if (err) {
            console.log(err);
            return;
          }

          // create indeterminate progress
          const unzipNotification = atom.notifications.addInfo(`Unzip and Load ${path.basename(url)}`, {
            detail: 'Unzipping and loading tessla image. This process may take about 1-2 minutes.',
            dismissable: true,
          });

          const indeterminateProgressWrapper = document.createElement('div');
          indeterminateProgressWrapper.classList.add('block');
          indeterminateProgressWrapper.appendChild(document.createElement('progress'));

          try {
            const unzipNotificationView = atom.views.getView(unzipNotification).element;
            const unzipNotificationContent = unzipNotificationView.querySelector('.detail-content');

            if (unzipNotificationContent) {
              unzipNotificationContent.appendChild(indeterminateProgressWrapper);
            }
          } catch(_) { /* now its not empty */ }

          // remember for later that the download was successful
          atom.config.set('tessla.alreadySetUpDockerContainer', true);

          // unzip file
          // fs.createReadStream(filePath).pipe(unzip.Extract({ path: path.dirname(filePath) }));
          const unzipper = new DecompressZip(filePath);

          unzipper.on('error', err => {
            console.log("catched error", err);

            // close notification
            unzipNotification.dismiss();
          });

          unzipper.on('extract', log => {
            //console.log("finished extracting", log);
            // load container
            childProcess.spawn('docker', ['rmi', 'tessla']).on('close', () => {
              const load = childProcess.spawn('docker', ['load', '-i', path.join(path.dirname(filePath), 'tessla')]);

              load.stdout.on('data', (data) => {
                console.log(data.toString());
              });

              load.on('close', () => {
                // start docker container
                const dockerArgs = ['run', '--volume', `${path.join(os.homedir(), '.tessla-env')}:/tessla`, '-w', '/tessla', '-tid', '--name', 'tessla', 'tessla', 'sh'];
                childProcess.spawnSync('docker', dockerArgs);

                // close notification
                unzipNotification.dismiss();
              })
            });
          });

          unzipper.on('progress', (fileIndex, fileCount) => {
            console.log('Extracted file ' + (fileIndex + 1) + ' of ' + fileCount);
          });

          unzipper.extract({
            path: path.dirname(filePath),
            filter: (file) => { return true; }
          });
        });

        // call callback
        callback();
      }).pipe(fs.createWriteStream(filePath));

      // if the abort button is clicked we will stop the progress
      abortBtn.addEventListener('click', () => {
        req.abort();
      });
    };

    const stop = () => {
      // close notification window
      notification.dismiss();
    }

    // create button for the notification
    const btnWrapper = document.createElement('div');
    btnWrapper.classList.add('btn-toolbar');

    const startButton = document.createElement('a');
    startButton.innerHTML = 'Download';
    startButton.classList.add('btn', 'btn-info');
    startButton.addEventListener('click', start);

    const stopButton = document.createElement('a');
    stopButton.innerHTML = 'No thanks';
    stopButton.classList.add('btn', 'btn-info');
    stopButton.addEventListener('click', stop);

    btnWrapper.appendChild(startButton);
    btnWrapper.appendChild(stopButton);

    // now try to get the notification to include some buttons
    try {
      // get notification content in which the button should be placed
      const notificationView = atom.views.getView(notification).element;
      const notificationContent = notificationView.querySelector('.detail-content');

      if (notificationContent) {
        notificationContent.appendChild(btnWrapper);
      }
    } catch (_) { /* not empty now */ }
  }
}
