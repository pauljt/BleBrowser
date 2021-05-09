/*global
    Puck, uk, window, describe, it, expect, str2ab
*/
/*jslint es6
*/


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

describe('2 Pucks', function () {
    "use strict";
    it('should be independent, connectable, readable, and disconnectable', async function () {
        let next_step_h3 = document.getElementById('next-action');
        if (!next_step_h3) {
            throw 'No #next-action element';
        }

        let progress_tests_button = document.getElementById('progress-test');
        if (!progress_tests_button) {
            throw 'No #progress-test button.';
        }
        function userContinuePromise() {
            return new Promise(function (resolve) {
                next_step_h3.innerHTML = 'Hit "Progress test"';
                progress_tests_button.onclick = function () {
                    console.log('User continuing...');
                    next_step_h3.innerHTML = '...';
                    resolve();
                };
            });
        }

        function getConnectedDevicePromise(msg, options) {
            return userContinuePromise().then(function () {

                if (!options) {
                    options = {acceptAllDevices: true};
                }

                next_step_h3.innerHTML = msg;
                return navigator.bluetooth.requestDevice(options).then(function (device) {
                    next_step_h3.innerHTML = '...';
                    return device.gatt.connect().then(() => device);
                });
            });
        }

        function getConnectedPuckPromise(msg) {
            return getConnectedDevicePromise(msg, {
                filters: [{
                    namePrefix: 'Puck.js',
                    services: [NORDIC_SERVICE]
                }]
            });
        }

        let charPromiseResolve = {};
        let deviceBuffers = {};

        function charNotification(event) {
            console.log(`charNotification ${event.target.service.device.name} ${ab2str(event.target.value.buffer)}`);
            let did = event.target.service.device.id;
            if (deviceBuffers[did] === undefined) {
                deviceBuffers[did] = '';
            }
            deviceBuffers[did] += ab2str(event.target.value.buffer);
            console.log(`${event.target.service.device.name} buffer now ${deviceBuffers[did]}`);
        }

        async function deviceBufferMatches(did, match) {
            const start = Date.now();
            return new Promise((resolve, reject) => {
                const tid = setInterval(() => {
                    if ((deviceBuffers[did] || '').search(match) !== -1) {
                        console.log(`Matched ${match}`);
                        deviceBuffers[did] = '';
                        clearInterval(tid);
                        resolve();
                        return;
                    }

                    const now = Date.now();
                    if (start + 2000 < now) {
                        console.log(`Timeout waiting for ${match} (buffer ${deviceBuffers[did]})`);
                        clearInterval(tid);
                        reject('Timeout');
                        return;
                    }
                }, 1);
            });
        }

        const devs = [
            await getConnectedPuckPromise('Pick a first puck'),
            await getConnectedPuckPromise('Pick a second puck'),
        ];
        expect(devs.every(d => d !== undefined)).toBeTruthy();
        expect(devs[0].id).not.toBe(devs[1].id);

        async function resetCheckDevice(device) {
            const service = await device.gatt.getPrimaryService(NORDIC_SERVICE);
            const [rxChar, txChar] = await Promise.all([
                service.getCharacteristic(NORDIC_RX),
                service.getCharacteristic(NORDIC_TX),
            ]);
            expect(rxChar).toBeDefined();
            expect(txChar).toBeDefined();

            rxChar.addEventListener('characteristicvaluechanged', charNotification);
            txChar.addEventListener('characteristicvaluechanged', charNotification);

            await rxChar.startNotifications();
            await txChar.writeValue(str2ab("echo(true);\n"));
            await deviceBufferMatches(device.id, '\n>$');
            await txChar.writeValue(str2ab("reset();\n"));
            await deviceBufferMatches(device.id, '\n>$');
            await txChar.writeValue(str2ab("echo(false);\n"));
            await txChar.writeValue(str2ab("print('echoing');\n"));
            await deviceBufferMatches(device.id, 'echoing');

            device.rxChar = rxChar;
            device.txChar = txChar;
        }

        console.log(`await resets and initial echoes`);
        await Promise.all(devs.map(resetCheckDevice));

        // OK, so now we ask them both to print hello.
        console.log(`await hellos`);
        await Promise.all(devs.map((dev, ind) => Promise.all([
            dev.txChar.writeValue(str2ab(`print('${ind}');\n`)),
            deviceBufferMatches(dev.id, `${ind}`),
        ])));

        next_step_h3.innerHTML = 'Disconnect both pucks (e.g. remove the battery).';
        await Promise.all(devs.map(dev => new Promise(resolve => dev.addEventListener(
            'gattserverdisconnected',
            (ev) => {
                expect(ev.target).toBe(dev);
                resolve();
            },
        ))));
    }, 60000);
});
