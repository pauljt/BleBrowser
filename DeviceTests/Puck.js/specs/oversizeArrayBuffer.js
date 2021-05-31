describe('Oversize ArrayBuffer', function () {
  "use strict";
  it('should not break the bluetooth connection', async function () {
    const puck = await getConnectedPuck('Select a puck (to test sending a view on a large buffer)');
    const service = await puck.gatt.getPrimaryService(NORDIC_SERVICE);
    const [rxChar, txChar] = await Promise.all([
      service.getCharacteristic(NORDIC_RX),
      service.getCharacteristic(NORDIC_TX),
    ]);

    let output = '';
    let waiter;
    function charNotification(event) {
      output += ab2str(event.target.value.buffer);
      console.log(`charNotification output now ${output}`);
      if (waiter) {
        waiter();
      }
    }

    async function waitFor(match) {
      return new Promise((resolve) => {
        waiter = () => {
          if (output.search(match) !== -1) {
            console.log(`Got match ${match}`);
            expect(`Got match ${match}`).toBeTruthy();
            waiter = undefined;
            output = '';
            resolve();
          }
        };
      });
    }

    rxChar.addEventListener('characteristicvaluechanged', charNotification);
    await rxChar.startNotifications();

    // check we're echoing
    await txChar.writeValue(str2ab('echo(true);\n'));
    await waitFor('\n>$');

    const message = 'print("bigbuf");\n';

    // 32 meg should do it
    let buffer = new ArrayBuffer(3200000);
    let view8 = new Uint8Array(buffer, 10000, message.length);
    for (let ii = 0; ii < message.length; ii += 1) {
      view8[ii] = message.charCodeAt(ii);
    }

    console.log(`write value ${view8} buffer length ${view8.buffer.length}`);
    txChar.writeValue(view8);
    await waitFor('bigbuf');

    puck.gatt.disconnect();
  }, 30000);
});
