Launch Screen.xib

# Literally just a static view to flash at launch, configured in .xcodeproj 



Main.storyboard

- ViewController

    - containerView
    - locationTextField
    - userController: WKUserContentController 
    - webBluetoothManager: WebBluetoothManager // javascript webkit interaction message handler
    - webView: WKWebView
        - configuration: WKWebViewConfiguration
            - userContentController: WKUserContentController
                - handlers: like([String: WKScriptMessageHandler]) = ["bluetooth": WebBluetoothManager]
  
    - viewDidLoad()
        // sets up webBluetoothManager, userController
    

- View
    - subviews [containerView, locationTextField]

- App Delegate, AppDelegate.swift // does nothing very interesting


## BLE

WebBluetoothManager: WKScriptMessageHandler, CBCentralManagerDelegate, PopUpPickerViewDelegate

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
