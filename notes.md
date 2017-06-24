Launch Screen.xib

# Literally just a static view to flash at launch, configured in .xcodeproj 

Main.storyboard

- ViewController

    - containerView
    - locationTextField
    - userController: WKUserContentController 
    - WBManager: WBManager // javascript webkit interaction message handler
    - webView: WKWebView
        - configuration: WKWebViewConfiguration
            - userContentController: WKUserContentController
                - handlers: like([String: WKScriptMessageHandler]) = ["bluetooth": WBManager]
  
    - viewDidLoad()
        // sets up WBManager, userController
    

- View
    - subviews [containerView, locationTextField]

- App Delegate, AppDelegate.swift // does nothing very interesting


## BLE

WBManager: WKScriptMessageHandler, CBCentralManagerDelegate, PopUpPickerViewDelegate

    - userContentController(WKUserContentController, WKScriptMessage):
    - 


## WebKit

WKScriptMessage

    - body: oneof(NSNumber, NSString, NSDate, NSArray, NSDictionary, NSNull)
    // e.g. ["type": "bluetooth:requestDevice", "callbackID": 0, "data": ["filters": ..., "name": ...]]
    - webView: WKWebView
    - frameInfo: WKFrameInfo
    - name // the handler name 



WKFrameInfo
    - isMainFrame
    - request: URLRequest
    - securityOrigin: WKSecurityOrigin


1. message arrives
2. triaged by bluetooth manager

1. handle requestDevice
2. bluetooth manager parks the transaction, from now if more transactions come in for requestDevice they are rejected
   - there is only one requestDevice transaction so correlator can be static

2. handle device.connectGATT
   - got device UUID

## Future enhancements

1. Console window to make it easier to debug on the device.
3. full screen option


## Done in 1.0.0

1. Handle spontaneous disconnects
2. Add forward / back buttons.
a. disable / enable forward / back buttons depending on whether there is something to go back or forward to.
3. Get HTTPS up on website.
4. Read characteristics
5. clear state after navigation
8. gatt server disconnect
10. Icon
9. rename GATTCharacteristic to RemoteGATTCharacteristic
11. Done + Cancel when no devices are in range

## TODO before shipping 1.0.0

10. Complete test plan and test
11. Push GPS changes to site.
12. Remove security exceptions.
13. Check version numbers.
14. Send to App store.

## Version 1.1

1. bookmarks

## Version 1.1.1

1. save last location and restore on relaunch, rather than just going to the same place all the time.
2. fix open in a new window link bug
3. fix base 64 decoding error
4. add window.alert.

## Version 1.1.2

1. Fix allowing selection of any devices using acceptAllDevices flag.
2. Fix allowing selection of devices using the "name" filter flag.
2. display address and name of device in picker view.

## Version 1.2

1. native logging window
2. iCloud bookmarks
3. work with Gordon's IDE
4. security contexts

## Smallish bugs

1. Characteristics are not de-notified / torn down when device disconnects
2. Handling of devices with the same UUIDs (internal / external) is non-existent.
3. in BluetoothGATTService.getCharacteristic check we got the correct char UUID back.
4. Going back doesn't refresh the page, but state has been lost meaning there's a lack of sync between page and native
5. Don't handle filters properly, if you specify `[{namePrefix: "puck", services: ["xyz"]}, {namePrefix: "other", services: ["abc"]}]` this will offer a device with name `"puck"` and service `"abc"`.
6. Calling `getCharacteristic()` more than once on a service not well defined... i.e. we should return the same object that we created before if we have it, but we probably create a new one... and this will cause problems if we've registered for notifications on it already.

## Large limitations

1. Device associations with web addresses do not persist on navigation, including page refresh.
2. Not clear how attempting to select / use multiple devices is going to work.
3. events not propagated 
4. Descriptors not supported
5. Services within services not supported
6. no bookmarks

## Weird stuff

1. UUIDs are uppercase in apple land, lower case on the web, sigh.
