import UIKit
import WebKit

class ViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate,WKUIDelegate {

    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var containerView: UIView!
    
    var devicePicker: PopUpPickerView!
    
    var webView: WKWebView!
    var webBluetoothManager:WebBluetoothManager!
    
    override func viewDidLoad() {
       
        super.viewDidLoad()
        locationTextField.delegate = self
        
        //load polyfill script
        var script:String?
        if let filePath:String = NSBundle(forClass: ViewController.self).pathForResource("WebBluetooth", ofType:"js") {
            do {
                script = try NSString(contentsOfFile: filePath, encoding: NSUTF8StringEncoding) as String
            } catch _ {
                print("Error loading polyfil")
                return
            }
        }
        
        //create bluetooth object, and set it to listen to messages
        webBluetoothManager = WebBluetoothManager();
        let webCfg:WKWebViewConfiguration = WKWebViewConfiguration()
        let userController:WKUserContentController = WKUserContentController()
        userController.addScriptMessageHandler(webBluetoothManager, name: "bluetooth")
        
        // connect picker
        devicePicker = PopUpPickerView()
        devicePicker.delegate = webBluetoothManager
        self.view.addSubview(devicePicker)
        webBluetoothManager.devicePicker = devicePicker
        
        //add the bluetooth script prior to loading all frames
        let userScript:WKUserScript =  WKUserScript(source: script!, injectionTime: WKUserScriptInjectionTime.AtDocumentEnd, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        webCfg.userContentController = userController;
        
        
        webView = WKWebView(
            frame: self.containerView.bounds,
            configuration:webCfg
        )
        webView.UIDelegate = self
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        containerView.addSubview(webView)
        
        let views = ["webView": webView]
        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[webView]|",
            options: NSLayoutFormatOptions(), metrics: nil, views: views))
        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[webView]|",
            options: NSLayoutFormatOptions(), metrics: nil, views: views))
        
        loadLocation("https://pauljt.github.io/bletest/") 
    }
    

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        loadLocation(textField.text!)
        return true
    }
    
    func loadLocation(var location: String) {
        if !location.hasPrefix("http://") && !location.hasPrefix("https://") {
            location = "http://" + location
        }
        locationTextField.text = location
        webView.loadRequest(NSURLRequest(URL: NSURL(string: location)!))
        
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        locationTextField.text = webView.URL?.absoluteString
        
    }
    
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        locationTextField.text = webView.URL?.absoluteString
        webView.loadHTMLString("<p>Fail Navigation: \(error.localizedDescription)</p>", baseURL: nil)
    }
    
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        locationTextField.text = webView.URL?.absoluteString
        webView.loadHTMLString("<p>Fail Provisional Navigation: \(error.localizedDescription)</p>", baseURL: nil)
    }
    
    func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (() -> Void)) {
        print("webView:\(webView) runJavaScriptAlertPanelWithMessage:\(message) initiatedByFrame:\(frame) completionHandler:\(completionHandler)")
        
        let alertController = UIAlertController(title: frame.request.URL?.host, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: { action in
            completionHandler()
        }))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    
}
