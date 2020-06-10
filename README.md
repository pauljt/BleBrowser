# WebBLE

Initial partial implementation of the [Web Bluetooth](https://webbluetoothcg.github.io/web-bluetooth/) 
spec for iOS. 

This builds on [Paul Thierault](https://github.com/pauljt)'s [original implementation](https://github.com/pauljt/BleBrowser).

The app is fundamentally a `WKWebView` with a polyfill providing the javascript APIs calling 
through to the CoreBluetooth iOS API via a thin transaction management layer.

WebBLE is licensed under the Apache Version 2.0 License as per the LICENSE file.

## Supported APIs v1.0

### `navigator.bluetooth`

- `.requestDevice(options)`
  - `options.acceptAllDevices = true` to ask for any device
  - `options.filters` is a list of filters (mutually exclusive with `acceptAllDevices`) with properties
    - `name`: devices with the given name will be included
    - `namePrefix`: devices with names with this prefix will be included
    - `services`: list of service aliases or uuids.

### `BluetoothDevice`

- `.id`
- `.name`
- `.gatt`
- `.gattserverdisconnected: EventHandler`

### `BluetoothRemoteGATTServer`

- `.connected`
- `.connect()`
- `.disconnect()`
- `.getPrimaryService(uuid)`
- `.getPrimaryServices()`

### `BluetoothRemoteGATTService`

- `.uuid`
- `.device`
- `.getCharacteristic(uuid)`
- `.getCharacteristics`

### `BluetoothRemoteGATTCharacteristic`

- `.service`
- `.uuid`
- `.value`
- `.readValue()`
- `.writeValue(value)`
- `.oncharacteristicvaluechanged: EventHandler`
- `.startNotifications()`
- `.stopNotifications()`
- `.addEventListener()`
- `.removeEventListener()`


Everything else is TBD!
