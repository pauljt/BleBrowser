/*global
    Puck, uk, window, describe, fit, it, expect, str2ab, NORDIC_SERVICE, navigator
*/
/*jslint es6
*/
describe('Camera', function () {
    // "use strict";

    it('should get the camera', async function () {
        const constraints = { audio: true, video: true };

        setNextAction('Hit yes to get the camera');
        let stream;
        try {
            stream = await navigator.mediaDevices.getUserMedia(constraints);
        }
        finally {
            setNextAction('...');
        }
        expect(stream).toBeDefined();
        expect(stream.active).toBeTruthy();

        stream.getTracks().forEach(t => t.stop());
        expect(stream.active).toBeFalsy();
    });
});
