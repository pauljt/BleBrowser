import UIKit
import WebKit

class ViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate,WKUIDelegate {

    @IBOutlet weak var locationTextField: UITextField!

    @IBOutlet var goBackButton: UIBarButtonItem!
    @IBOutlet var goForwardButton: UIBarButtonItem!
    @IBOutlet var refreshButton: UIBarButtonItem!
    
    @IBOutlet var webView: WBWebView!
    var wbManager: WBManager? {
        didSet {
            self.webView.wbManager = wbManager
        }
    }

    @IBAction func reload() {
        if (self.webView?.url?.absoluteString ?? "about:blank") == "about:blank",
            let text = self.locationTextField.text,
            !text.isEmpty {
            self.loadLocation(text)
        } else {
            self.webView.reload()
        }
    }
    
    override func viewDidLoad() {
       
        super.viewDidLoad()
        locationTextField.delegate = self

        // connect view to manager
        self.webView.wbManager = self.wbManager
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self

        for path in ["canGoBack", "canGoForward"] {
            self.webView.addObserver(self, forKeyPath: path, options: NSKeyValueObservingOptions.new, context: nil)
        }

        let svers = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        self.loadLocation("https://www.greenparksoftware.co.uk/projects/webble/\(svers)")

        self.goBackButton.target = self.webView
        self.goBackButton.action = #selector(self.webView.goBack)
        self.goForwardButton.target = self.webView
        self.goForwardButton.action = #selector(self.webView.goForward)
        self.refreshButton.target = self
        self.refreshButton.action = #selector(self.reload)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        self.loadLocation(textField.text!)
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

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let man = self.wbManager {
            man.clearState()
        }
        self.wbManager = WBManager()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let urlString = webView.url?.absoluteString,
            urlString != "about:blank" {
            locationTextField.text = urlString
        }
        
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.loadHTMLString("<p>Fail Navigation: \(error.localizedDescription)</p>", baseURL: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
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

    // MARK: observe protocol
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard
            let defKeyPath = keyPath,
            let defChange = change
        else {
            NSLog("Unexpected change with either no keyPath or no change dictionary!")
            return
        }

        switch defKeyPath {
        case "canGoBack":
            self.goBackButton.isEnabled = defChange[NSKeyValueChangeKey.newKey] as! Bool
        case "canGoForward":
            self.goForwardButton.isEnabled = defChange[NSKeyValueChangeKey.newKey] as! Bool
        default:
            NSLog("Unexpected change observed by ViewController: \(keyPath)")
        }
    }
}
