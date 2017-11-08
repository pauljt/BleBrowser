/*jslint
        browser
*/
/*global
        atob, Event, uk, window
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
    "use strict";

    let wbutils = uk.co.greenparksoftware.wbutils;
    nslog("Initialize web bluetooth runtime");

    if (navigator.bluetooth) {
        // already exists, don't polyfill
        nslog('navigator.bluetooth already exists, skipping polyfill');
        return;
    }

    let native;

    function _arrayBufferToBase64(buffer) {
        let binary = '';
        let bytes = new Uint8Array(buffer);
        bytes.forEach(function (byte) {
            binary += String.fromCharCode(byte);
        });
        return window.btoa(binary);
    }

    function str64todv(str64) {
        // Return a DataView from a base64 encoded DOM String.
        let str16 = atob(str64);
        let ab = new Int8Array(str16.length);
        let ii;
        for (ii = 0; ii < ab.length; ii += 1) {
            // trusted interface, so don't check this is 0 <= charCode < 256
            ab[ii] = str16.charCodeAt(ii);
        }
        return new DataView(ab.buffer);
    }

    //
    // We need an EventTarget implementation. This one nicked wholesale from
    // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget
    //
    nslog("Build EventTarget");
    function EventTarget() {
        this.listeners = {};
    }

    EventTarget.prototype.addEventListener = function (type, callback) {
        if (this.listeners[type] === undefined) {
            this.listeners[type] = [];
        }
        this.listeners[type].push(callback);
    };
    EventTarget.prototype.removeEventListener = function (type, callback) {

        let stack = this.listeners[type];
        if (stack === undefined) {
            return;
        }
        let l = stack.length;
        let ii;
        for (ii = 0; ii < l; ii += 1) {
            if (stack[ii] === callback) {
                stack.splice(ii, 1);
                return this.removeEventListener(type, callback);
            }
        }
    };
    EventTarget.prototype.dispatchEvent = function (event) {
        let stack = this.listeners[event.type];
        if (stack === undefined) {
            return;
        }
        event.currentTarget = this;
        stack.forEach(function (cb) {
            try {
                cb.call(this, event);
            } catch (e) {
                nslog(`Exception dispatching to callback ${cb}: ${e}`);
            }
        });
    };

    //
    // And this function is how we add EventTarget to the "sub"classes.
    //
    function mixin(target, src) {
        Object.assign(target.prototype, src.prototype);
        target.prototype.constructor = target;
    }

    function defineROProperties(target, roDescriptors) {
        Object.keys(roDescriptors).forEach(function (key) {
            Object.defineProperty(target, key, {value: roDescriptors[key]});
        });
    }

    // https://webbluetoothcg.github.io/web-bluetooth/ interface
    nslog("Create BluetoothDevice");
    function BluetoothDevice(deviceJSON) {
        EventTarget.call(this);

        let roProps = {
            adData: {},
            deviceClass: deviceJSON.deviceClass || 0,
            id: deviceJSON.id,
            gatt: new native.BluetoothRemoteGATTServer(this),
            productId: deviceJSON.productId || 0,
            productVersion: deviceJSON.productVersion || 0,
            uuids: deviceJSON.uuids,
            vendorId: deviceJSON.vendorId || 0,
            vendorIdSource: deviceJSON.vendorIdSource || "bluetooth"
        };
        defineROProperties(this, roProps);

        this.name = deviceJSON.name;

        if (deviceJSON.adData) {
            this.adData.appearance = deviceJSON.adData.appearance || "";
            this.adData.txPower = deviceJSON.adData.txPower || 0;
            this.adData.rssi = deviceJSON.adData.rssi || 0;
            this.adData.manufacturerData = deviceJSON.adData.manufacturerData || [];
            this.adData.serviceData = deviceJSON.adData.serviceData || [];
        }
    }

    BluetoothDevice.prototype = {
        toString: function () {
            return `BluetoothDevice(${this.id.slice(0, 10)})`;
        },
        handleSpontaneousDisconnectEvent: function () {
            // Code references as per
            // https://webbluetoothcg.github.io/web-bluetooth/#disconnection-events
            // 1. not implemented
            // 2.
            if (!this.gatt.connected) {
                return;
            }
            // 3.1
            this.gatt.connected = false;
            // 3.2-3.7 not implemented
            // 3.8
            this.dispatchEvent(new native.BluetoothEvent("gattserverdisconnected", this));
        }
    };
    mixin(BluetoothDevice, EventTarget);

    nslog("Create BluetoothRemoteGATTServer");
    function BluetoothRemoteGATTServer(webBluetoothDevice) {
        if (webBluetoothDevice === undefined) {
            throw new Error("Attempt to create BluetoothRemoteGATTServer with no device");
        }
        defineROProperties(this, {device: webBluetoothDevice});
        this.connected = false;
        this.connectionTransactionIDs = [];
    }
    BluetoothRemoteGATTServer.prototype = {
        connect: function () {
            let self = this;
            let tid = native.getTransactionID();
            this.connectionTransactionIDs.push(tid);
            return this.sendMessage("connectGATT", {callbackID: tid})
                .then(function () {
                    self.connected = true;
                    native.registerDeviceForNotifications(self.device);
                    self.connectionTransactionIDs.splice(
                        self.connectionTransactionIDs.indexOf(tid),
                        1
                    );

                    return self;
                });
        },
        disconnect: function () {
            this.connectionTransactionIDs.forEach((tid) => native.cancelTransaction(tid));
            this.connectionTransactionIDs = [];
            let self = this;
            return this.sendMessage("disconnectGATT")
                .then(function () {
                    native.unregisterDeviceForNotifications(self.device);
                    self.connected = false;
                });
        },
        getPrimaryService: function (UUID) {
            let canonicalUUID = window.BluetoothUUID.getService(UUID);
            let self = this;
            return this.sendMessage("getPrimaryService", {data: {serviceUUID: canonicalUUID}})
                .then(() => new native.BluetoothRemoteGATTService(
                    self.device,
                    canonicalUUID,
                    true
                ));
        },

        getPrimaryServices: function (UUID) {
            if (true) {
                throw new Error("Not implemented");
            }
            let device = this.device;
            let canonicalUUID = window.BluetoothUUID.getService(UUID);
            return this.sendMessage("getPrimaryServices", {data: {serviceUUID: canonicalUUID}})
                .then(function (servicesJSON) {
                    let servicesData = JSON.parse(servicesJSON);
                    let services = servicesData;
                    services = device;
                    services = [];

                    // this is a problem - all services will have the same information (UUID) so no way for this side of the code to differentiate.
                    // we need to add an identifier GUID to tell them apart
                    // servicesData.forEach(
                    //     (service) => services.push(
                    //         new native.BluetoothRemoteGATTService(device, canonicalUUID, true)
                    //     )
                    // );
                    return services;
                });
        },
        sendMessage: function (type, messageParms) {
            messageParms = messageParms || {};
            messageParms.data = messageParms.data || {};
            messageParms.data.deviceId = this.device.id;
            return native.sendMessage("device:" + type, messageParms);
        },
        toString: function () {
            return "BluetoothRemoteGATTServer(" + this.device.toString() + ")";
        }
    };

    nslog("Create BluetoothRemoteGATTService");
    function BluetoothRemoteGATTService(device, uuid, isPrimary) {
        if (device === undefined || uuid === undefined || isPrimary === undefined) {
            throw new Error("Invalid call to BluetoothRemoteGATTService constructor");
        }
        defineROProperties(this, {
            device: device,
            uuid: uuid,
            isPrimary: isPrimary
        });
    }

    BluetoothRemoteGATTService.prototype = {
        getCharacteristic: function (uuid) {
            let canonicalUUID = BluetoothUUID.getCharacteristic(uuid);
            let service = this;
            return this.sendMessage(
                "getCharacteristic",
                {data: {characteristicUUID: canonicalUUID}}
            ).then(function (CharacteristicJSON) {
                nslog(`Got characteristic ${uuid}`);
                return new native.BluetoothRemoteGATTCharacteristic(
                    service,
                    canonicalUUID,
                    CharacteristicJSON.properties
                );
            });
        },
        getCharacteristics: function (ignore) {
            throw new Error('Not implemented');
        },
        getIncludedService: function (ignore) {
            throw new Error('Not implemented');
        },
        getIncludedServices: function (ignore) {
            throw new Error('Not implemented');
        },
        sendMessage: function (type, messageParms) {
            messageParms = messageParms || {};
            messageParms.data = messageParms.data || {};
            messageParms.data.serviceUUID = this.uuid;
            return this.device.gatt.sendMessage(type, messageParms);
        },
        toString: function () {
            return ("BluetoothRemoteGATTService(" + this.uuid + ")");
        }
    };

    nslog("Create BluetoothRemoteGATTCharacteristic");
    function BluetoothRemoteGATTCharacteristic(service, uuid, properties) {
        nslog(`New BluetoothRemoteGATTCharacteristic ${uuid}`);
        let roProps = {
            service: service,
            properties: properties,
            uuid: uuid
        };
        defineROProperties(this, roProps);
        this.value = null;
        EventTarget.call(this);
        native.registerCharacteristicForNotifications(this);
    }

    BluetoothRemoteGATTCharacteristic.prototype = {
        getDescriptor: function (ignore) {
            throw new Error('Not implemented');
        },
        getDescriptors: function (ignore) {
            throw new Error("Not implemented");
        },
        readValue: function () {
            let char = this;
            return this.sendMessage("readCharacteristicValue")
                .then(function (valueEncoded) {
                    char.value = str64todv(valueEncoded);
                    return char.value;
                });
        },
        writeValue: function (value) {
            // Can't send raw array bytes since we use JSON, so base64 encode.
            let v64 = _arrayBufferToBase64(value);
            return this.sendMessage("writeCharacteristicValue", {data: {value: v64}});
        },
        startNotifications: function () {
            return this.sendMessage("startNotifications");
        },
        stopNotifications: function () {
            return this.sendMessage("stopNotifications");
        },
        sendMessage: function (type, messageParms) {
            messageParms = messageParms || {};
            messageParms.data = messageParms.data || {};
            messageParms.data.characteristicUUID = this.uuid;
            return this.service.sendMessage(type, messageParms);
        },
        toString: function () {
            return (
                "BluetoothRemoteGATTCharacteristic(" + this.service.toString() + ", " +
                this.uuid + ")"
            );
        }
    };
    mixin(BluetoothRemoteGATTCharacteristic, EventTarget);

    nslog("Create BluetoothGATTDescriptor");
    function BluetoothGATTDescriptor(characteristic, uuid) {
        defineROProperties(this, {characteristic: characteristic, uuid: uuid});
    }

    BluetoothGATTDescriptor.prototype = {
        get writableAuxiliaries() {
            return this.value;
        },
        readValue: function () {
            throw new Error("Not implemented");
        },
        writeValue: function () {
            throw new Error("Not implemented");
        }
    };

    nslog("Create bluetooth");
    let bluetooth = {};
    bluetooth.requestDevice = function (requestDeviceOptions) {
        if (!requestDeviceOptions) {
            return Promise.reject(new TypeError("requestDeviceOptions not provided"));
        }
        let acceptAllDevices = requestDeviceOptions.acceptAllDevices;
        let filters = requestDeviceOptions.filters;
        if (acceptAllDevices) {
            if (filters && filters.length > 0) {
                return Promise.reject(new TypeError("acceptAllDevices was true but filters was not empty"));
            }
            return native.sendMessage("requestDevice", {data: {acceptAllDevices: true}})
                .then(function (device) {
                    return new BluetoothDevice(device);
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

        return native.sendMessage("requestDevice", {data: validatedDeviceOptions})
            .then(function (device) {
                return new BluetoothDevice(device);
            });
    };

    function BluetoothEvent(type, target) {
        defineROProperties(this, {type: type, target: target});
    }
    BluetoothEvent.prototype = {
        prototype: Event.prototype,
        constructor: BluetoothEvent
    };

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
            trans(false, "Premature cancellation.");
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
                throw new Error("CallRemote should never be called without a type!");
            }

            sendMessageParms = sendMessageParms || {};
            let data = sendMessageParms.data || {};
            let callbackID = sendMessageParms.callbackID || this.getTransactionID();
            message = {
                type: type,
                data: data,
                callbackID: callbackID
            };

            nslog(`--> sending ${type} ${JSON.stringify(data)}`);
            window.webkit.messageHandlers.bluetooth.postMessage(message);

            this.messageCount += 1;
            return new Promise(function (resolve, reject) {
                native.callbacks[callbackID] = function (success, result) {
                    if (success) {
                        resolve(result);
                    } else {
                        reject(result);
                    }
                    delete native.callbacks[callbackID];
                };
            });
        },
        receiveMessageResponse: function (success, resultString, callbackID) {
            nslog(`<-- receiving response ${success} ${resultString} ${callbackID}`);

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
                    throw new Error("Device already registered for notifications");
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
            nslog(`<-- device disconnect event ${deviceId}`);
            let devices = native.devicesBeingNotified[deviceId];
            if (devices !== undefined) {
                nslog(`Device not registered for notifications`);
                devices.forEach(function (device) {
                    device.handleSpontaneousDisconnectEvent();
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
            nslog("receiveCharacteristicValueNotification");
            const cid = BluetoothUUID.getCharacteristic(cname);
            let devChars = native.characteristicsBeingNotified[deviceId];
            let chars = devChars && devChars[cid];
            if (chars === undefined) {
                nslog(
                    `Unexpected characteristic value notification for device ` +
                    `${deviceId} and characteristic ${cid}`,
                );
                return;
            }
            nslog("<-- char val notification", cid, d64);
            chars.forEach(function (char) {
                let dataView = str64todv(d64);
                char.value = dataView;
                char.dispatchEvent(new BluetoothEvent("characteristicvaluechanged", char));
            });
        },
        enableBluetooth: function () {
            // weirdly this can get overwritten, so add a way to enable it.
            navigator.bluetooth = bluetooth;
        },
        // defeat the linter's "out of scope" warnings for not yet defined functions
        BluetoothRemoteGATTCharacteristic: BluetoothRemoteGATTCharacteristic,
        BluetoothRemoteGATTServer: BluetoothRemoteGATTServer,
        BluetoothRemoteGATTService: BluetoothRemoteGATTService,
        BluetoothEvent: BluetoothEvent
    };

    // Exposed interfaces
    window.BluetoothDevice = BluetoothDevice;
    window.BluetoothUUID = BluetoothUUID;
    window.iOSNativeAPI = native;
    window.receiveDeviceDisconnectEvent = native.receiveDeviceDisconnectEvent;
    window.receiveMessageResponse = native.receiveMessageResponse;
    window.receiveCharacteristicValueNotification = native.receiveCharacteristicValueNotification;

    // Patches
    // Patch window.open so it doesn't attempt to open in a separate window or tab ever.
    function open(location) {
        window.location = location;
    }
    window.open = open;
    nslog('WBPolyfill complete');
}());
