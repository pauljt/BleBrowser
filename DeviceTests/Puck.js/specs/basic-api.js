/*global
    Puck, uk, window, describe, fit, it, expect, str2ab, NORDIC_SERVICE
*/
/*jslint es6
*/

describe('Basic API', function () {
    "use strict";

    it('should fail promise on bad params to requestDevice', function (complete) {

        let badParams = [
            // undefined,
            null,
            {},
            {filters: []},
            {acceptAllDevices: false},
            {acceptAllDevices: true, filters: [{services: [NORDIC_SERVICE]}]},
            {filters: [{services: ["not-really-a-service"]}]}
        ];
        Promise.all(badParams.map(function (params) {

            navigator.bluetooth.requestDevice(params).then(function () {
                expect(false).toBe(true);
            }).catch(function (err) {
                expect(err).toBeDefined();
            });
        })).then(complete);
    }, 10000);

    it('should raise on bad parameters', function (complete) {

        function TestFailure() {
            return null;
        }

        let a = {
            testRequestDeviceAll: function () {
                this.setNextAction(
                    "Check all devices are available and cancel the dialog."
                );
                let self = this;
                return navigator.bluetooth.requestDevice({acceptAllDevices: true})
                    .then(function (ignore) {
                        throw new TestFailure("Device request should have been cancelled.");
                    })
                    .catch(function (error) {
                        self.assertEqual(error, "User cancelled");
                    });
            },
            testRequestDeviceSingleNamePrefix: function () {
                this.setNextAction("Cancel the dialog.");
                let self = this;
                return navigator.bluetooth.requestDevice({filters: [
                    {namePrefix: "MyPuck"}
                ]})
                    .then(function (ignore) {
                        throw new TestFailure("Device request should have been cancelled.");
                    })
                    .catch(function (error) {
                        self.assertEqual(error, "User cancelled");
                    });
            },
            testRequestDeviceSingleService: function () {
                this.setNextAction("Cancel the dialog.");
                let self = this;
                return navigator.bluetooth.requestDevice({filters: [
                    {services: ["6e400001-b5a3-f393-e0a9-e50e24dcca9e"]}
                ]})
                    .then(function (ignore) {
                        throw new TestFailure("Device request should have been cancelled.");
                    })
                    .catch(function (error) {
                        self.assertEqual(error, "User cancelled");
                    });
            }
        };
        a = a;
        complete();
    });
});
