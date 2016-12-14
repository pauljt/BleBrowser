# BleBrowser

Initial partial implementation of the [Web Bluetooth](https://webbluetoothcg.github.io/web-bluetooth/) 
spec for iOS, to get some basics working. 

This builds on [Paul Thierault](https://github.com/pauljt)'s [original implementation](https://github.com/pauljt/BleBrowser).

The app is fundamentally a `WKWebView` with a polyfill providing the javascript APIs calling 
through to the CoreBluetooth iOS API via a thin transaction management layer.

## Supported APIs

### `navigator.bluetooth.requestDevice()`

- `.requestDevice(options)`

### `BluetoothDevice`

- `.id`
- `.name`
- `.gatt`

### `BluetoothRemoteGATTServer`

- `.connected`
- `.connect()`
- `.disconnect()`
- `.getPrimaryService(uuid)`

### `BluetoothGATTService`

- `.uuid`
- `.device`
- `.getCharacteristic(uuid)`

### `BluetoothGATTCharacteristic`

- `.service`
- `.uuid`
- `.value`
- `.readValue()`
- `.writeValue(value)`

## Non-supported APIs but planned for development soon

### `BluetoothDevice`

- `.gattserverdisconnected: EventHandler`

### `BluetoothGATTCharacteristic`

- `.oncharacteristicvaluechanged: EventHandler`
- `.startNotifications()`
- `.stopNotifications()`
- `.addEventListener()`
- `.removeEventListener()`

Everything else is TBD!
