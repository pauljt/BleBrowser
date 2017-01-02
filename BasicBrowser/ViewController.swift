import UIKit
import WebKit

class ViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate,WKUIDelegate {

    @IBOutlet weak var locationTextField: UITextField!

    @IBOutlet var goBackButton: UIBarButtonItem!
    @IBOutlet var goForwardButton: UIBarButtonItem!
    @IBOutlet var refreshButton: UIBarButtonItem!
    
    @IBOutlet var webView: WBWebView!
    var wbManager = WBManager()
    
    override func viewDidLoad() {
       
        super.viewDidLoad()
        locationTextField.delegate = self

        // connect view to manager
        self.webView.wbManager = self.wbManager
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self

        self.loadLocation("http://caliban.local:8000/projects/puck.js/0.1.0/puckdemo")

        NSLog("WebView Frame \(self.webView.frame)")

        self.goBackButton.target = self.webView
        self.goBackButton.action = #selector(self.webView.goBack)
        self.goForwardButton.target = self.webView
        self.goForwardButton.action = #selector(self.webView.goForward)
        self.refreshButton.target = self.webView
        self.refreshButton.action = #selector(self.webView.reload)
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
        self.webView.load(URLRequest(url: URL(string: location)!))
        
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
