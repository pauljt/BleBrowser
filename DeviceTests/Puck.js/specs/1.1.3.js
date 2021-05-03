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
    it('should be independent, connectable, readable, and disconnectable', function (complete) {
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

        function getConnectedDevicePromise(options) {
            return userContinuePromise().then(function () {

                if (!options) {
                    options = {acceptAllDevices: true};
                }

                next_step_h3.innerHTML = 'Pick a device';
                return navigator.bluetooth.requestDevice(options).then(function (device) {
                    next_step_h3.innerHTML = '...';
                    return device.gatt.connect().then(() => device);
                });
            });
        }

        function getConnectedPuckPromise() {
            return getConnectedDevicePromise({
                filters: [{
                    namePrefix: 'Puck.js',
                    services: [NORDIC_SERVICE]
                }]
            });
        }

        let dev1;
        let dev2;
        let charPromiseResolve = {};

        function charNotification(event) {
            let did = event.target.service.device.id;
            if (!charPromiseResolve[did]) {
                console.log('Dumping char notification');
                return;
            }
            charPromiseResolve[did](event);
        }
        function promiseToTextReceivedFromDevice(dev, lbl) {
            let promise = new Promise(function (resolve) {
                let buffer = '';
                charPromiseResolve[dev.id] = function (event) {
                    let edev = event.target.service.device;
                    expect(edev).toBe(dev);
                    let value = event.target.value.buffer;
                    buffer += ab2str(value);
                    if (buffer.includes(lbl)) {
                        charPromiseResolve[dev.id] = undefined;
                        resolve();
                    }
                };
            });
            return promise;
        }

        return Promise.resolve().then(function () {
            console.log('Get connected puck 1');
            return getConnectedPuckPromise().then(function (dev) {
                dev1 = dev;
                expect(dev1).toBeDefined();
                console.log('Get connected puck 2');
            }).then(() => getConnectedPuckPromise().then(function (dev) {
                dev2 = dev;
                expect(dev2).toBeDefined();
            })).then(() => expect(dev1.id).not.toBe(dev2.id));

        }).then(function () {

            function buttonPressPromise(device) {
                console.log(`Get primary NORDIC_SERVICE for ${device.name}`);
                return device.gatt.getPrimaryService(NORDIC_SERVICE).then(function (service) {
                    console.log(`Get NORDIC characteristics for ${device.name}`);
                    return Promise.all([
                        service.getCharacteristic(NORDIC_RX),
                        service.getCharacteristic(NORDIC_TX)
                    ]);
                }).then(function (chars) {
                    device.rx_char = chars[0];
                    device.tx_char = chars[1];
                    chars.forEach((char) => char.addEventListener(
                        'characteristicvaluechanged',
                        charNotification
                    ));
                    console.log(`Start notifications on ${device.name}`);
                    return device.rx_char.startNotifications().then(
                        () => {
                            console.log(`Send reset on ${device.name}`);
                            return device.tx_char.writeValue(str2ab('\r\nreset();\r\n'));
                        }
                    ).then(function () {
                        console.log(`Check output from ${device.name}`);
                        return Promise.all([
                            promiseToTextReceivedFromDevice(device, 'echo(false)'),
                            (function () {
                                return device.tx_char.writeValue(str2ab('echo(false);\r\n'));
                            }())
                        ]);
                    });
                }).then(() => device);
            }

            return Promise.all([
                buttonPressPromise(dev1),
                buttonPressPromise(dev2)
            ]);

        }).then(function () {
            // OK, so now we ask them both to print hello.
            let devs = [[dev1, 'dev1'], [dev2, 'dev2']];
            return Promise.all(devs.map(function (tuple) {
                let dev = tuple[0];
                let lbl = tuple[1];
                console.log(`Ask device to say hello ${dev.name}`);
                return Promise.all([
                    promiseToTextReceivedFromDevice(dev, lbl),
                    dev.tx_char.writeValue(str2ab("print('" + lbl + "');\n"))
                ]);
            }));
        }).then(function () {

            // we can address and control different devices independently
            // check we can disconnect both.
            let devs = [dev1, dev2];
            return Promise.all(devs.map(function (dev) {
                next_step_h3.innerHTML = 'Disconnect both pucks (e.g. remove the battery).';
                return new Promise(function (resolve) {
                    dev.addEventListener('gattserverdisconnected', function (event) {
                        expect(event.target).toBe(dev);
                        resolve();
                    });
                });
            }));
        }).then(function () {
            next_step_h3.innerHTML = '';
        }).then(function () {
            let devs = [dev1, dev2];
            devs.map(function (dev) {
                dev.tx_char.removeEventListener('characteristicvaluechanged', charNotification);
            });
            complete();
        }).catch(function (error) {
            expect(error).toBeUndefined();
            complete();
        });

    }, 60000);
});
