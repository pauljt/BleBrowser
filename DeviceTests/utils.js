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
