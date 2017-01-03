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



## TODO before shipping 1.0.0

1. Handle spontaneous disconnects
2. Add forward / back buttons.
3. Get HTTPS up on website.
4. Read characteristics
5. clear state after navigation
6. native logging window
7. should readValue return the value or should we just rely on notifications
8. gatt server disconnect
9. rename GATTCharacteristic to RemoteGATTCharacteristic

## Smallish bugs

1. Characteristics are not de-notified / torn down when device disconnects
2. Handling of devices with the same UUIDs (internal / external) is non-existent.

## Large limitations

1. Device associations with web addresses do not persist on navigation, including page refresh.
2. Not clear how attempting to select / use multiple devices is going to work.
3. events not propagated 
4. Descriptors not supported
5. Services within services not supported

## Weird stuff

1. UUIDs are uppercase in apple land, lower case on the web, sigh.
