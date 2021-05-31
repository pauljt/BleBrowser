/*global
        atob, Event, nslog, uk, window
*/
// https://webbluetoothcg.github.io/web-bluetooth/ interface
(function () {
  'use strict';

  const wb = uk.co.greenparksoftware.wb;
  const wbutils = uk.co.greenparksoftware.wbutils;

  wb.BluetoothRemoteGATTServer = function (webBluetoothDevice) {
    if (webBluetoothDevice === undefined) {
      throw new Error('Attempt to create BluetoothRemoteGATTServer with no device');
    }
    wbutils.defineROProperties(this, {device: webBluetoothDevice});
    this.connected = false;
    this.connectionTransactionIDs = [];
  };
  wb.BluetoothRemoteGATTServer.prototype = {
    connect: function () {
      let self = this;
      let tid = wb.native.getTransactionID();
      this.connectionTransactionIDs.push(tid);
      return this.sendMessage('connectGATT', {callbackID: tid}).then(function () {
        self.connected = true;
        wb.native.registerDeviceForNotifications(self.device);
        self.connectionTransactionIDs.splice(
          self.connectionTransactionIDs.indexOf(tid),
          1
        );

        return self;
      });
    },
    disconnect: function () {
      this.connectionTransactionIDs.forEach((tid) => wb.native.cancelTransaction(tid));
      this.connectionTransactionIDs = [];
      if (!this.connected) {
        return;
      }
      this.connected = false;

      // since we've set connected false this event won't be generated
      // by the shortly to be dispatched disconnect event.
      this.device.dispatchEvent(new wb.BluetoothEvent('gattserverdisconnected', this.device));
      wb.native.unregisterDeviceForNotifications(this.device);
      // If there were two devices pointing at the same underlying device
      // this would break both connections, so not really what we want,
      // but leave it like this till someone complains.
      this.sendMessage('disconnectGATT');
    },
    getPrimaryService: async function (uuid) {
      if (!uuid) {
        return Promise.reject(new Error('getPrimaryService requires a UUID'));
      }
      const services = await this.getPrimaryServices(uuid);
      return services[0];
    },
    getPrimaryServices: async function (uuid) {
      const data = {
      data: uuid ? {serviceUUID: window.BluetoothUUID.getService(uuid)} : {},
      };
      const serviceUUIDs = await this.sendMessage('getPrimaryServices', data);
      return serviceUUIDs.map(uuidInner => new wb.BluetoothRemoteGATTService(
        this.device,
        window.BluetoothUUID.getService(uuidInner),
        true,
      ));
    },
    sendMessage: async function (type, messageParms) {
      messageParms = messageParms || {};
      messageParms.data = messageParms.data || {};
      messageParms.data.deviceId = this.device.id;
      return await wb.native.sendMessage('device:' + type, messageParms);
    },
    toString: function () {
      return `BluetoothRemoteGATTServer(${this.device.toString()})`;
    },
  };
})();
