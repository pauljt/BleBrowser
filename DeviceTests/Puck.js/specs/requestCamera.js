/*global
    Puck, uk, window, describe, fit, it, expect, str2ab, NORDIC_SERVICE, navigator
*/
/*jslint es6
*/
describe('Camera', function () {
    // "use strict";

    it('should get the camera', async function () {
        // const devices = await navigator.mediaDevices.enumerateDevices();
        // const devices = await navigator.enumerateDevices();

        // expect(devices.length).toBeGreaterThan(0);

        const constraints = { audio: true, video: true };

        // ⚠️⚠️⚠️ Going to polyfill these apis following https://ba.net/check-webrtc/
        console.log(window.MediaStreamTrack);
        console.log(window.MediaDevice);
        console.log(navigator.mediaDevices);
        console.log(navigator.enumerateDevices);

        const stream = await navigator.webkitGetUserMedia(constraints);
        expect(stream).toBeDefined();
        expect(stream.active).toBeTruthy();

        delete stream;
        stream.getTracks().forEach(t => t.stop());


        expect(stream.active).toBeFalsy();
    });
});
