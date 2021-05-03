/*global
    Puck, uk, window, describe, fit, it, expect, str2ab, NORDIC_SERVICE, navigator
*/
/*jslint es6
*/
var CHUNKSIZE = 16;

describe('readCharacteristic', function () {
    "use strict";

    function str2ab(str) {
        var buf = new ArrayBuffer(str.length);
        var bufView = new Uint8Array(buf);
        for (var i=0, strLen=str.length; i<strLen; i++) {
          bufView[i] = str.charCodeAt(i);
        }
        return buf;
    }

    function ab2str(buf) {
        return String.fromCharCode.apply(null, new Uint8Array(buf));
    }

    let next_step_h3;

    beforeEach(() => {
        next_step_h3 = document.getElementById('next-action');
        next_step_h3.innerHTML = '';
    });

    afterAll(() => {
       next_step_h3.innerHTML = 'DONE';
    })

    it('should read a pucks terminal characteristic', function (complete) {
        next_step_h3.innerHTML = 'Connect to a puck';
        var puck;
        var rx;
        var tx;
        navigator.bluetooth.requestDevice({acceptAllDevices: true})
        .then(function (device) {
            console.log(`got device`);
            return device.gatt.connect();
        })
        .then(function (server) {
            console.log(`got gatt server`);
            puck = server.device;
            return server.getPrimaryService(NORDIC_SERVICE);
        })
        .then(function (service) {
            console.log(`got NORDIC_SERVICE`);
            return Promise.all([
                service.getCharacteristic(NORDIC_RX),
                service.getCharacteristic(NORDIC_TX),
            ]);
        })
        .then(function (rx_tx) {
            console.log(`got rx tx`);
            rx = rx_tx[0];
            tx = rx_tx[1];
            // rx.addEventListener('characteristicvaluechanged', function(event) {
            //     var value = event.target.value.buffer; // get arraybuffer
            //     console.log(`NORDIC_RX data: ${ab2str(value)}`);
            // });
            // return rx.startNotifications();
            return rx.readValue().then(function (value) {
                console.log(`initial value: ${ab2str(value.buffer)}`);
            });
        })
        .then(function () {
            console.log(`writing value`);
            return tx.writeValue(str2ab('console.log(\'he\')\n'));//.then(function () {
            //     console.log(`second write`);
            //     tx.writeValue('llo\');\n');
            // });
        })
        .then(function () {
            console.log(`setting Timeout`);
            return new Promise(setTimeout);
        })
        .then(function () {
            return rx.readValue().then(function (value) {
                console.log(`>${ab2str(value.buffer)}`);
            });
        })
        .then(function () {
            console.log(`setting Timeout`);
            return new Promise(setTimeout);
        })
        .then(function () {
            return rx.readValue().then(function (value) {
                console.log(`>${ab2str(value.buffer)}`);
            });
        })
        .then(function () {
            console.log(`setting Timeout`);
            return new Promise(setTimeout);
        })
        .then(function () {
            return rx.readValue().then(function (value) {
                console.log(`>${ab2str(value.buffer)}`);
            });
        })
        .then(complete)
        .catch(function (e) {
            console.error(`ERROR FAILURE ${e}`);
            complete.fail(e);
        })
        .then(function () {
            if (puck) {
                console.log(`disconnecting gatt`);
                puck.gatt.disconnect();
            }
        });
    }, 20000);

    // it('should not allow long namePrefix', function (complete) {
    //     navigator.bluetooth.requestDevice({ filters: [{ namePrefix: longString }] }).then(
    //         res => expect('path').toEqual('invalid'),
    //     ).catch(exc => expect(`${exc}`).toMatch(/Invalid filter namePrefix/)).then(complete);
    // });

    // it('should allow a name prefix which is Puck', function (complete) {
    //     navigator.bluetooth.requestDevice({ filters: [{ namePrefix: 'Puck' }] }).then(
    //         dev => expect(dev).toBeDefined(),
    //     ).catch(exc => expect(exc).not.toBeDefined()).then(complete);
    // }, 20000);

    // it('should not find anything with a random name prefix which is Puck', function (complete) {
    //     next_step_h3.innerHTML = 'Power up a puck, but you should not see it appear as it is not' +
    //     'filtered in, so cancel';
    //     navigator.bluetooth.requestDevice({ filters: [{ namePrefix: 'gobblededook' }] }).then(
    //         dev => expect(dev).toBeDefined(),
    //     ).catch(exc => expect(`${exc}`).toMatch(/User cancelled/)).then(complete);
    // }, 20000);
});
