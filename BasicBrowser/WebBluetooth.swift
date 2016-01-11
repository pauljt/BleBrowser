//
//  WebBluetooth.swift
//  BasicBrowser
//
//  Created by Paul Theriault on 10/01/2016.
//

import Foundation
import CoreBluetooth
import WebKit

class WebBluetooth: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, WKScriptMessageHandler {
    
    // BLE
    var centralManager:CBCentralManager!
    var peripheral:CBPeripheral!
    
    var webView:WKWebView!
    
    let jsfile="bluetooth.js"
    
    override init(){
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // simple brigde to native based on Goldengate
    // and https://github.com/radex/Goldengate
    // from http://stackoverflow.com/a/30477309
    // (with less deferred)
    
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage){
        
        let messageBody = message.body as! NSDictionary
        let method = messageBody["method"] as! String
        let args = transformArguments(messageBody["arguments"] as! [AnyObject])
        let callbackID = messageBody["callbackID"] as! Int
        
        print("Received message #\(callbackID) to dispatch \(method)(\(args))")
        let result:Dictionary = ["result":"winning"]
        let success = true
        do {
            let resultData = try NSJSONSerialization.dataWithJSONObject(result, options: NSJSONWritingOptions(rawValue: 0))
            let resultOrReason = NSString(data:resultData, encoding:NSUTF8StringEncoding)!
            let command:String = "recieveMessage(\(callbackID), \(success), \(resultOrReason))"
            print(command)
            
            message.webView!.evaluateJavaScript("console.log('here')",completionHandler: nil);
            message.webView!.evaluateJavaScript(command, completionHandler: nil)
        }
        catch {
            print("json error: \(error)")
        }
    }
    
    func transformArguments(args: [AnyObject]) -> [AnyObject!] {
        return args.map { arg in
            if arg is NSNull {
                return nil
            } else {
                return arg
            }
        }
    }
    
    
    
    // Check status of BLE hardware
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            central.scanForPeripheralsWithServices(nil, options: nil)
            print("scanning")
        }
        else {
            print("Error:Bluetooth switched off or not initialized")
        }
    }
    
    // find device
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        print("found")
        
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        print("found:", nameOfDeviceFound)
        //self.centralManager.stopScan()
        //self.peripheral = peripheral
        //self.peripheral.delegate = self
                     }
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Connected, looking for services")
        peripheral.discoverServices(nil)
    }
    
    
    // connect services
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        print( "Looking at peripheral services")
        for service in peripheral.services! {
            
            
            switch service.UUID.UUIDString{
           
            default:
                print("Service found:",service)
            }
            peripheral.discoverCharacteristics(nil, forService: service)
            
        }
    }
    
    // connect characteristics
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        for characteristic in service.characteristics! {
            switch characteristic.UUID.UUIDString{
                
            default:
                print("characteristic:",characteristic,characteristic.UUID.UUIDString)
                
            }
            peripheral.setNotifyValue(true, forCharacteristic: characteristic)
        }
    }
    
    // subscribe to characteristic updates
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("Characteristic Updated:",characteristic.UUID," ->",characteristic.value)
        
    }
    
}
