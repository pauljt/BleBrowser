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



Bluetooth Manager option 1 (Current design)

- 1 <-> 1 ViewController, lives for the lifetime of the programme.
  a) devices globally retained and linked to source URL, and never released.

- 2 

## TODO before shipping 1.0.0

1. Handle spontaneous disconnects
2. Add forward / back buttons.
3. Get HTTPS up on website.
4. Read characteristics

## Limitations

1. Device associations with web addresses do not persist on navigation, including page refresh.
2. Not clear how attempting to select / use multiple devices is going to work.
3. Handling of devices with the same UUIDs (internal / external) is non-existent.
