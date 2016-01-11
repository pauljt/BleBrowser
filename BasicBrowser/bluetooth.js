// Based on https://github.com/WebBluetoothCG/chrome-app-polyfill
//

(function () {
  "use strict";


  function canonicalUUID(uuidAlias) {
    uuidAlias >>>= 0; // Make sure the number is positive and 32 bits.
    var strAlias = "0000000" + uuidAlias.toString(16);
    strAlias = strAlias.substr(-8);
    return strAlias + "-0000-1000-8000-00805f9b34fb";
  }

  if (navigator.bluetooth) {
    // navigator.bluetooth already exists; not polyfilling.
    if (!window.BluetoothUUID) {
      window.BluetoothUUID = {};
    }
    if (!window.BluetoothUUID.canonicalUUID) {
      window.BluetoothUUID.canonicalUUID = canonicalUUID;
    }
    return;
  }
  if (!window.webkit || !webkit.messageHandlers.bluetooth) {
    console.warn("Not loaded inside IoS WKWebView with polyfill injected");
    //todo return;
  }

  var uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;


  window.BluetoothUUID = {};
  window.BluetoothUUID.canonicalUUID = canonicalUUID;

  navigator.bluetooth = {};

  navigator.bluetooth.requestDevice = function () {
    return sendMessage("bluetooth.requestDevice", Array.prototype.slice.call(arguments))
      /*.then(function (device) {
        return new BluetoothDevice(device);
      });*/
  };

  function BluetoothDevice(nativeBluetoothDevice) {
    console.log("got device:", nativeBluetoothDevice)
    this._id = nativeBluetoothDevice.id;
    this._name = nativeBluetoothDevice.name;

    //there's clearly a better way
    this._adData = {};
    this._adData.appearance = this.nativeBluetoothDevice.appearance;
    this._adData.txPower = this.nativeBluetoothDevice.txPower;
    this._adData.rssi = this.nativeBluetoothDevice.rssi;
    this._adData.manufacturerData = this.nativeBluetoothDevice.manufacturerData;
    this._adData.serviceData = this.nativeBluetoothDevice.serviceData;

    this._deviceClass = nativeBluetoothDevice.deviceClass
    this._vendorIdSource = nativeBluetoothDevice.vendorIdSource;
    this._vendorId = nativeBluetoothDevice.vendorId;
    this._productId = nativeBluetoothDevice.productId;
    this._productVersion = nativeBluetoothDevice.productVersion;
    this._paired = nativeBluetoothDevice.paired;
    this._connected = nativeBluetoothDevice.connected;
    this._gattServer = nativeBluetoothDevice._gattServer;
    this._uuids = nativeBluetoothDevice.uuids;
  };

  window.BluetoothDevice = BluetoothDevice;

  BluetoothDevice.prototype = {

    get id() {
      return this._id;
    },
    get name() {
      return this._name;
    },
    get adData() {
      return this._adData;
    },
    get deviceClass() {
      return this._deviceClass;
    },
    get vendorIdSource() {
      return this._vendorIdSource;
    },
    get vendorId() {
      return this._vendorId;
    },
    get productId() {
      return this._productId;
    },
    get productVersion() {
      return this._productVersion;
    },
    get paired() {
      return this._paired;
    },
    get connected() {
      return this._connected;
    },
    get gattServer() {
      return this._gattServer;
    },
    get uuids() {
      return this._uuids;
    },

    connectGatt: function () {
      console.log("not implemented")
    },

    toString: function () {
      return self._id;
    }
  };

  var _messageCount = 0;
  var _callbacks = {};

  function sendMessage(method, args) {
    var callbackID, message;
    callbackID = _messageCount;
    message = {
      method: method,
      "arguments": args,
      callbackID: callbackID
    };
    window.webkit.messageHandlers.bluetooth.postMessage(message);
    _messageCount++;
    return new Promise(function (resolve, reject) {
      _callbacks[callbackID] = function (isSuccess, valueOrReason) {
        console.log("Got response2:", valueOrReason);
        if (isSuccess) {
          resolve(valueOrReason);
        } else {
          reject(valueOrReason);
        }
        //return delete _callbacks[callbackID];
      };
    });
  }

  function recieveMessage(callbackID, isSuccess, valueOrReason) {
    console.log("Got response1:", valueOrReason);
    _callbacks[callbackID](isSuccess, valueOrReason);
  }

  window.recieveMessage = recieveMessage;

})();


/*




 interface BluetoothAdvertisingData {
 readonly attribute unsigned short? appearance;
 readonly attribute byte? txPower;
 readonly attribute byte? rssi;
 readonly attribute Map manufacturerData;
 readonly attribute Map serviceData;
 };

 interface BluetoothGATTRemoteServer {
 readonly attribute BluetoothDevice device;
 readonly attribute boolean connected;
 void disconnect();
 Promise<BluetoothGATTService> getPrimaryService(BluetoothServiceUUID service);
 Promise<sequence<BluetoothGATTService>>
 getPrimaryServices(optional BluetoothServiceUUID service);
 };
 BluetoothGATTRemoteServer implements EventTarget;
 BluetoothGATTRemoteServer implements CharacteristicEventHandlers;
 BluetoothGATTRemoteServer implements ServiceEventHandlers;

 interface BluetoothGATTService {
 readonly attribute BluetoothDevice device;
 readonly attribute UUID uuid;
 readonly attribute boolean isPrimary;
 Promise<BluetoothGATTCharacteristic>
 getCharacteristic(BluetoothCharacteristicUUID characteristic);
 Promise<sequence<BluetoothGATTCharacteristic>>
 getCharacteristics(optional BluetoothCharacteristicUUID characteristic);
 Promise<BluetoothGATTService>
 getIncludedService(BluetoothServiceUUID service);
 Promise<sequence<BluetoothGATTService>>
 getIncludedServices(optional BluetoothServiceUUID service);
 };
 BluetoothGATTService implements EventTarget;
 BluetoothGATTService implements CharacteristicEventHandlers;
 BluetoothGATTService implements ServiceEventHandlers;

 interface BluetoothGATTCharacteristic {
 readonly attribute BluetoothGATTService service;
 readonly attribute UUID uuid;
 readonly attribute BluetoothCharacteristicProperties properties;
 readonly attribute ArrayBuffer? value;
 Promise<BluetoothGATTDescriptor> getDescriptor(BluetoothDescriptorUUID descriptor);
 Promise<sequence<BluetoothGATTDescriptor>>
 getDescriptors(optional BluetoothDescriptorUUID descriptor);
 Promise<ArrayBuffer> readValue();
 Promise<void> writeValue(BufferSource value);
 Promise<void> startNotifications();
 Promise<void> stopNotifications();
 };
 BluetoothGATTCharacteristic implements EventTarget;
 BluetoothGATTCharacteristic implements CharacteristicEventHandlers;

 interface BluetoothCharacteristicProperties {
 readonly attribute boolean broadcast;
 readonly attribute boolean read;
 readonly attribute boolean writeWithoutResponse;
 readonly attribute boolean write;
 readonly attribute boolean notify;
 readonly attribute boolean indicate;
 readonly attribute boolean authenticatedSignedWrites;
 readonly attribute boolean reliableWrite;
 readonly attribute boolean writableAuxiliaries;
 };

 interface BluetoothGATTDescriptor {
 readonly attribute BluetoothGATTCharacteristic characteristic;
 readonly attribute UUID uuid;
 readonly attribute ArrayBuffer? value;
 Promise<ArrayBuffer> readValue();
 Promise<void> writeValue(BufferSource value);
 };

 [NoInterfaceObject]
 interface CharacteristicEventHandlers {
 attribute EventHandler oncharacteristicvaluechanged;
 };

 [NoInterfaceObject]
 interface ServiceEventHandlers {
 attribute EventHandler onserviceadded;
 attribute EventHandler onservicechanged;
 attribute EventHandler onserviceremoved;
 };

 typedef DOMString UUID;
 interface BluetoothUUID {
 static UUID getService((DOMString or unsigned long) name);
 static UUID getCharacteristic((DOMString or unsigned long) name);
 static UUID getDescriptor((DOMString or unsigned long) name);

 static UUID canonicalUUID([EnforceRange] unsigned long alias);
 };

 typedef (DOMString or unsigned long) BluetoothServiceUUID;
 typedef (DOMString or unsigned long) BluetoothCharacteristicUUID;
 typedef (DOMString or unsigned long) BluetoothDescriptorUUID;

 partial interface Navigator {
 readonly attribute Bluetooth bluetooth;
 };


 */
