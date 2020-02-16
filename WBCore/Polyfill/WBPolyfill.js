/*jslint
        browser
*/
/*global
        atob, Event, nslog, uk, window
*/
//  Copyright 2016-2017 Paul Theriault and David Park. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// adapted from chrome app polyfill https://github.com/WebBluetoothCG/chrome-app-polyfill

(function () {
  'use strict';

  const wb = uk.co.greenparksoftware.wb;
  const wbutils = uk.co.greenparksoftware.wbutils;
  nslog('Initialize web bluetooth runtime');

  if (navigator.bluetooth) {
    // already exists, don't polyfill
    nslog('navigator.bluetooth already exists, skipping polyfill');
    return;
  }

  let native;

  nslog('Create BluetoothGATTDescriptor');
  function BluetoothGATTDescriptor(characteristic, uuid) {
    wbutils.defineROProperties(this, {characteristic: characteristic, uuid: uuid});
  }

  BluetoothGATTDescriptor.prototype = {
    get writableAuxiliaries() {
      return this.value;
    },
    readValue: function () {
      throw new Error('Not implemented');
    },
    writeValue: function () {
      throw new Error('Not implemented');
    }
  };

  nslog('Create bluetooth');
  let bluetooth = {};
  bluetooth.requestDevice = function (requestDeviceOptions) {
    if (!requestDeviceOptions) {
      return Promise.reject(new TypeError('requestDeviceOptions not provided'));
    }
    let acceptAllDevices = requestDeviceOptions.acceptAllDevices;
    let filters = requestDeviceOptions.filters;
    if (acceptAllDevices) {
      if (filters && filters.length > 0) {
        return Promise.reject(new TypeError('acceptAllDevices was true but filters was not empty'));
      }
      return native.sendMessage(
        'requestDevice', {data: {acceptAllDevices: true}}
      ).then(function (device) {
        return new wb.BluetoothDevice(device);
      });
    }

    if (!filters || filters.length === 0) {
      return Promise.reject(new TypeError('No filters provided and acceptAllDevices not set'));
    }
    try {
      filters = Array.prototype.map.call(filters, wbutils.canonicaliseFilter);
    } catch (e) {
      return Promise.reject(e);
    }
    let validatedDeviceOptions = {};
    validatedDeviceOptions.filters = filters;

    // Optional services not yet suppoprted.
    // let optionalServices = requestDeviceOptions.optionalServices;
    // if (optionalServices) {
    //     optionalServices = optionalServices.services.map(window.BluetoothUUID.getService);
    //     validatedDeviceOptions.optionalServices = optionalServices;
    // }
    return native.sendMessage(
      'requestDevice',
      {data: validatedDeviceOptions}
    ).then(function (device) {
      return new wb.BluetoothDevice(device);
    });
  };

  function BluetoothEvent(type, target) {
    wbutils.defineROProperties(this, {type, target, srcElement: target});
  }
  BluetoothEvent.prototype = {
    prototype: Event.prototype,
    constructor: BluetoothEvent
  };
  wb.BluetoothEvent = BluetoothEvent;

  //
  // ===== Communication with Native =====
  //
  native = {
    messageCount: 0,
    callbacks: {}, // callbacks for responses to requests

    cancelTransaction: function (tid) {
      let trans = this.callbacks[tid];
      if (!trans) {
        nslog(`No transaction ${tid} outstanding to fail.`);
        return;
      }
      delete this.callbacks[tid];
      trans(false, 'Premature cancellation.');
    },
    getTransactionID: function () {
      let mc = this.messageCount;
      do {
        mc += 1;
      } while (native.callbacks[mc] !== undefined);
      this.messageCount = mc;
      return this.messageCount;
    },
    sendMessage: function (type, sendMessageParms) {
      let message;
      if (type === undefined) {
        throw new Error('CallRemote should never be called without a type!');
      }

      sendMessageParms = sendMessageParms || {};
      let data = sendMessageParms.data || {};
      let callbackID = sendMessageParms.callbackID || this.getTransactionID();
      message = {
        type: type,
        data: data,
        callbackID: callbackID
      };

      nslog(`${type} ${callbackID}`);
      window.webkit.messageHandlers.bluetooth.postMessage(message);

      this.messageCount += 1;
      return new Promise(function (resolve, reject) {
        native.callbacks[callbackID] = function (success, result) {
          if (success) {
            nslog(`${type} ${callbackID} success`);
            resolve(result);
          } else {
            nslog(`${type} ${callbackID} failure ${JSON.stringify(result)}`);
            reject(result);
          }
          delete native.callbacks[callbackID];
        };
      });
    },
    receiveMessageResponse: function (success, resultString, callbackID) {
      if (callbackID !== undefined && native.callbacks[callbackID]) {
        native.callbacks[callbackID](success, resultString);
      } else {
        nslog(`Response for unknown callbackID ${callbackID}`);
      }
    },
    // of shape {deviceId: BluetoothDevice}
    devicesBeingNotified: {},
    registerDeviceForNotifications: function (device) {
      let did = device.id;
      if (native.devicesBeingNotified[did] === undefined) {
        native.devicesBeingNotified[did] = [];
      }
      let devs = native.devicesBeingNotified[did];
      devs.forEach(function (dev) {
        if (dev === device) {
          throw new Error('Device already registered for notifications');
        }
      });
      nslog(`Register device ${did} for notifications`);
      devs.push(device);
    },
    unregisterDeviceForNotifications: function (device) {
      let did = device.id;
      if (native.devicesBeingNotified[did] === undefined) {
        return;
      }
      let devs = native.devicesBeingNotified[did];
      let ii;
      for (ii = 0; ii < devs.length; ii += 1) {
        if (devs[ii] === device) {
          devs.splice(ii, 1);
          return;
        }
      }
    },
    receiveDeviceDisconnectEvent: function (deviceId) {
      nslog(`${deviceId} disconnected`);
      let devices = native.devicesBeingNotified[deviceId];
      if (devices !== undefined) {
        devices.forEach(function (device) {
          device.handleSpontaneousDisconnectEvent();
          native.unregisterDeviceForNotifications(device);
        });
      }
      native.characteristicsBeingNotified[deviceId] = undefined;
    },
    // shape: {deviceUUID: {characteristicUUID: [BluetoothRemoteGATTCharacteristic]}}
    characteristicsBeingNotified: {},
    registerCharacteristicForNotifications: function (characteristic) {

      let did = characteristic.service.device.id;
      let cid = characteristic.uuid;
      nslog(`Registering char UUID ${cid} on device ${did}`);

      if (native.characteristicsBeingNotified[did] === undefined) {
        native.characteristicsBeingNotified[did] = {};
      }
      let chars = native.characteristicsBeingNotified[did];
      if (chars[cid] === undefined) {
        chars[cid] = [];
      }
      chars[cid].push(characteristic);
    },
    receiveCharacteristicValueNotification: function (deviceId, cname, d64) {
      nslog('receiveCharacteristicValueNotification');
      const cid = window.BluetoothUUID.getCharacteristic(cname);
      let devChars = native.characteristicsBeingNotified[deviceId];
      let chars = devChars && devChars[cid];
      if (chars === undefined) {
        nslog(
          'Unexpected characteristic value notification for device ' +
          `${deviceId} and characteristic ${cid}`
        );
        return;
      }
      nslog('<-- char val notification', cid, d64);
      chars.forEach(function (char) {
        let dataView = wbutils.str64todv(d64);
        char.value = dataView;
        char.dispatchEvent(new BluetoothEvent('characteristicvaluechanged', char));
      });
    },
    enableBluetooth: function () {
      // weirdly this can get overwritten, so add a way to enable it.
      navigator.bluetooth = bluetooth;
    },
    // defeat the linter's "out of scope" warnings for not yet defined functions
    BluetoothRemoteGATTCharacteristic: wb.BluetoothRemoteGATTCharacteristic,
    BluetoothRemoteGATTServer: wb.BluetoothRemoteGATTServer,
    BluetoothRemoteGATTService: wb.BluetoothRemoteGATTService,
    BluetoothEvent: BluetoothEvent
  };
  wb.native = native;

  // Exposed interfaces
  window.BluetoothRemoteGATTCharacteristic = wb.BluetoothRemoteGATTCharacteristic;
  window.BluetoothRemoteGATTServer = wb.BluetoothRemoteGATTServer;
  window.BluetoothRemoteGATTService = wb.BluetoothRemoteGATTService;
  window.BluetoothDevice = wb.BluetoothDevice;
  window.iOSNativeAPI = native;
  window.receiveDeviceDisconnectEvent = native.receiveDeviceDisconnectEvent;
  window.receiveMessageResponse = native.receiveMessageResponse;
  window.receiveCharacteristicValueNotification = native.receiveCharacteristicValueNotification;

  nslog('call enableBluetooth!')
  native.enableBluetooth();

  // Patches
  // Patch window.open so it doesn't attempt to open in a separate window or tab ever.
  function open(location) {
    window.location = location;
  }
  window.open = open;
  nslog('WBPolyfill complete');
}());
