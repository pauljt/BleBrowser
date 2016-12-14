import UIKit
import WebKit

class ViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate,WKUIDelegate {

    class WKLogger: NSObject, WKScriptMessageHandler {
        open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            NSLog("WKLog: \(message.body)")
        }
    }

    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var containerView: UIView!
    let devicePicker = PopUpPickerView()
    
    var webView: WKWebView!
    var wbManager = WBManager()
    let wkLogger = WKLogger()
    
    override func viewDidLoad() {
       
        super.viewDidLoad()
        locationTextField.delegate = self
        
        //load polyfill script
        var script:String?
        if let filePath:String = Bundle(for: ViewController.self).path(forResource: "WebBluetooth", ofType:"js") {
            do {
                script = try NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue) as String
            } catch _ {
                print("Error loading polyfil")
                return
            }
        }

        // Before configuring the WKWebView, delete caches since
        // it seems a bit arbitrary when this happens otherwise.
        // This from http://stackoverflow.com/a/34376943/5920499
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]) as! Set<String>
        WKWebsiteDataStore.default().removeData(
            ofTypes: websiteDataTypes,
            modifiedSince: NSDate(timeIntervalSince1970: 0) as Date,
            completionHandler:{})

        //create bluetooth object, and set it to listen to messages
        let webCfg = WKWebViewConfiguration()
        let userController = WKUserContentController()
        userController.add(self.wbManager, name: "bluetooth")
        userController.add(self.wkLogger, name: "logger")

        // connect picker
        self.devicePicker.delegate = self.wbManager
        self.view.addSubview(devicePicker)
        self.wbManager.devicePicker = devicePicker
        
        // add the bluetooth script prior to loading all frames
        let userScript = WKUserScript(
            source: script!, injectionTime: .atDocumentStart,
            forMainFrameOnly: false)
        userController.addUserScript(userScript)
        webCfg.userContentController = userController
        
        webView = WKWebView(
            frame: self.containerView.bounds,
            configuration:webCfg
        )
        webView.uiDelegate = self
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        containerView.addSubview(webView)
        
        let views = ["webView": webView!]
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[webView]|",
            options: NSLayoutFormatOptions(), metrics: nil, views: views))
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[webView]|",
            options: NSLayoutFormatOptions(), metrics: nil, views: views))
        
        loadLocation("http://caliban.local:8000/projects/puck.js/0.1.0/puckdemo")
    }
    

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        loadLocation(textField.text!)
        return true
    }
    
    func loadLocation(_ location: String) {
        var location = location
        if !location.hasPrefix("http://") && !location.hasPrefix("https://") {
            location = "http://" + location
        }
        locationTextField.text = location
        webView.load(URLRequest(url: URL(string: location)!))
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        locationTextField.text = webView.url?.absoluteString
        
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        locationTextField.text = webView.url?.absoluteString
        webView.loadHTMLString("<p>Fail Navigation: \(error.localizedDescription)</p>", baseURL: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        locationTextField.text = webView.url?.absoluteString
        webView.loadHTMLString("<p>Fail Provisional Navigation: \(error.localizedDescription)</p>", baseURL: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (@escaping () -> Void)) {
        let alertController = UIAlertController(
            title: frame.request.url?.host, message: message,
            preferredStyle: .alert)
        alertController.addAction(UIAlertAction(
            title: "OK", style: .default, handler: {_ in completionHandler()}))
        self.present(alertController, animated: true, completion: nil)
    }
}
