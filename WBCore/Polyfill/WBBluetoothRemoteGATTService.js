/*jslint
        browser
*/
/*global
        atob, Event, nslog, uk, window
*/
//  Copyright 2020 David Park. All rights reserved.
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

  nslog('Create BluetoothRemoteGATTService');
  function BluetoothRemoteGATTService(device, uuid, isPrimary) {
    if (device === undefined || uuid === undefined || isPrimary === undefined) {
      throw new Error('Invalid call to BluetoothRemoteGATTService constructor');
    }
    wbutils.defineROProperties(this, {
      device: device,
      uuid: uuid,
      isPrimary: isPrimary
    });
  }

  BluetoothRemoteGATTService.prototype = {
    getCharacteristic: function (uuid) {
      let canonicalUUID = window.BluetoothUUID.getCharacteristic(uuid);
      let service = this;
      return this.sendMessage(
        'getCharacteristic',
        {data: {characteristicUUID: canonicalUUID}}
      ).then(function (CharacteristicJSON) {
        nslog(`Got characteristic ${uuid}`);
        return new wb.BluetoothRemoteGATTCharacteristic(
          service,
          canonicalUUID,
          CharacteristicJSON.properties
        );
      });
    },
    getCharacteristics: function () {
     return this.sendMessage(
       'getCharacteristics',
       {data: {}}
     ).then(function (characteristicsForServiceJSON) {
       nslog(`Got characteristics`);
            return {
            data: characteristicsForServiceJSON
            };
     });
    },
    getIncludedService: function () {
      throw new Error('Not implemented');
    },
    getIncludedServices: function () {
      throw new Error('Not implemented');
    },
    sendMessage: function (type, messageParms) {
      messageParms = messageParms || {};
      messageParms.data = messageParms.data || {};
      messageParms.data.serviceUUID = this.uuid;
      return this.device.gatt.sendMessage(type, messageParms);
    },
    toString: function () {
      return `BluetoothRemoteGATTService(${this.uuid})`;
    }
  };
  wb.BluetoothRemoteGATTService = BluetoothRemoteGATTService;
})();
