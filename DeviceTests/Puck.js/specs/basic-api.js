/*global
    Puck, uk, window, describe, fit, it, expect, str2ab, NORDIC_SERVICE
*/
/*jslint es6
*/

describe('Basic API', function () {
    "use strict";

    it('should fail promise on bad params to requestDevice', async function () {
        let badParams = [
            // undefined,
            null,
            {},
            {filters: []},
            {acceptAllDevices: false},
            {acceptAllDevices: true, filters: [{services: [NORDIC_SERVICE]}]},
            {filters: [{services: ["not-really-a-service"]}]}
        ];
        await Promise.all(badParams.map(async function (params) {
            try {
                const dev = await navigator.bluetooth.requestDevice(params);
                expect('Should not have got a device for invalid params').toBeFalsy();
            } catch (e) {
                expect(e).toBeDefined();
            }
        }));
    }, 10000);

    it('should populate userAgent', () => {
        // The part at the end is the extra application name user agent added by the WBWebView
        // generated from the bundle name and short version string.
        expect(navigator.userAgent).toMatch(/Mozilla.*iPhone.*\w+\/\d+(\.\d+(\.\d+)?)?$/);
    });
});
