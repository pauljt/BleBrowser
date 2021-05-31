function ab2str(buf) {
    "use strict";
    return String.fromCharCode.apply(null, new Uint8Array(buf));
}

function str2ab(str) {
    "use strict";
    let buf = new ArrayBuffer(str.length);
    let bufView = new Uint8Array(buf);
    let i;
    let strLen = str.length;
    for (i = 0; i < strLen; i += 1) {
        bufView[i] = str.charCodeAt(i);
    }
    return buf;
}

function setNextAction(action) {
  let stepH3 = document.getElementById('next-action');
  stepH3.innerHTML = action;
}
function clearNextAction() {
  setNextAction('');
}

function setProgressTestAction(action) {
  const but = document.getElementById('progress-test');
  if (!but) {
    throw new Error('No #progress-test button');
  }
  but.onclick = action;
}

async function progressTest(msg) {
  return new Promise(function (resolve) {
    setProgressTestAction(() => {
      console.log(`User continuing...`);
      setNextAction('...');
      resolve();
    });
    setNextAction(msg ? `Hit Progress test for "${msg}"` : 'Hit "Progress test"');
  });
}

async function getConnectedDevice(msg, options) {
  await progressTest(msg);

  if (!options) {
    options = {acceptAllDevices: true};
  }

  setNextAction(msg);
  const device = await navigator.bluetooth.requestDevice(options);
  setNextAction('...');
  await device.gatt.connect();
  return device;
}

async function getConnectedPuck(msg) {
  return await getConnectedDevice(msg, {
    filters: [{
      namePrefix: 'Puck.js',
      services: [NORDIC_SERVICE]
    }]
  });
}
