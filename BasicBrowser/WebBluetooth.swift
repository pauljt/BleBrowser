//
//  WebBluetooth.swift
//  BasicBrowser
//
//  Created by Paul Theriault on 10/01/2016.
//

import Foundation
import CoreBluetooth
import WebKit


//helpers for communicating with JS
struct JSRequest{
    var id:Int
    var method:String
    var args:[AnyObject]
}


struct BluetoothAdvertisingData{
    var appearance:String?
    var txPower:String?
    var rssi:String?
    var manufacturerData:String?
    var serviceData:[String]
    
    init(advertisementData: [String : AnyObject] = [String : AnyObject](), RSSI: NSNumber = 0){
        
        //self.txPower = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        self.rssi=String(RSSI)
        let data = advertisementData[CBAdvertisementDataManufacturerDataKey]
        if data != nil{
            if let dataString = NSString(data: data as! NSData, encoding: NSUTF8StringEncoding) as? String {
                self.manufacturerData = dataString;
            } else {
                print("not a valid UTF-8 sequence")
            }
        }
        
        var uuids = [String]()
        if advertisementData["kCBAdvDataServiceUUIDs"] != nil {
            uuids = (advertisementData["kCBAdvDataServiceUUIDs"] as! [CBUUID]).map{$0.UUIDString.lowercaseString}
        }
        self.serviceData = uuids
    }
    
}

struct BluetoothDevice{
    var id:String
    var name:String?
    var adData:BluetoothAdvertisingData
    var deviceClass:String?
    var vendorIDSource:String?
    var vendorID:String?
    var productID:String?
    var productVersion:String?
    var gattServer:BluetoothGATTRemoteServer?
    var uuids:[String]?
    
    init(peripheral:CBPeripheral? = nil,advertisementData:[String : AnyObject] = [String : AnyObject](),RSSI:NSNumber = 0){
        self.id = peripheral != nil ? peripheral!.identifier.UUIDString :"MOCK-DEVICE-UUID"
        self.name = peripheral != nil ? peripheral!.name :nil
        self.adData = BluetoothAdvertisingData(advertisementData:advertisementData,RSSI: RSSI)
    }
    
    func toJSON()->String?{
        let props = [
            "id": self.id,
            "name": self.name != nil ? self.name! : NSNull()
        ]
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(props,
                options: NSJSONWritingOptions(rawValue: 0))
            return String(data: jsonData, encoding: NSUTF8StringEncoding)
        } catch let error {
            print("error converting to json: \(error)")
            return nil
        }
    }
}

struct BluetoothGATTRemoteServer{
    
}


class WebBluetooth: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, WKScriptMessageHandler {
    
    override init(){
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    //too remove - only connect to bb-8 for now
    static let deviceName = "BB-7687"
    
    // BLE
    var centralManager:CBCentralManager!
    var peripheral:CBPeripheral!

    //stores the webView we are linked to
    var webView:WKWebView!

    var BluetoothDeviceOption_filters:[CBUUID]?
    var BluetoothDeviceOption_optionalService:[CBUUID]?
    
    // recieve message from javascript
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage){
        print ("got message")
        if(self.webView == nil){
            self.webView = message.webView
        }
    
        let request:JSRequest
            let messageBody = message.body as! NSDictionary
            let callbackID:Int =  messageBody["callbackID"] as! Int
            let method = messageBody["method"] as! String
            let args = transformArguments(messageBody["arguments"] as! [AnyObject])
            request = JSRequest(id: callbackID,method:method,args:args);
            print("Received message #\(callbackID) to dispatch \(method)(\(args))")
        
       
        switch request.method{
        case "bluetooth.requestDevice":
            
            let options = request.args[0]
            let filters = options["filters"] as! [AnyObject]
            let filterOne = filters[0]
            
            print("Filters",filters)
            print("Services",filterOne["services"])
            print("name:",filters[0]["name"])
            print("prefix:",filters[0]["namePrefix"])

            let services = filters[0]["services"] as! [String]
            
            let servicesCBUUID:[CBUUID]?
            
            //todo validate CBUUID (js does this already but security should be here since 
            //messageHandler can be called directly? Or can it?
            // (if the string is invalid, it causes app to crash with NSexception)
            servicesCBUUID = services.map {CBUUID(string:($0.uppercaseString))}
            print(servicesCBUUID)
            // really we should be scanning for servicesCBUUID here, not nil
            // but BB-8 isn't detected when searching this way, even though
            // it advertises the following:
            //   ["kCBAdvDataManufacturerData": <3330>, "kCBAdvDataIsConnectable": 1, "kCBAdvDataServiceUUIDs": (
            //    "22BB746F-2BA0-7554-2D6F-726568705327"
            //    ), "kCBAdvDataTxPowerLevel": 6, "kCBAdvDataLocalName": BB-7687]
            // IE replacing nil with [CBUUID(string:"22BB746F-2BA0-7554-2D6F-726568705327")] doesnt work??
            // todo figure out why this is...
            centralManager.scanForPeripheralsWithServices(servicesCBUUID, options: nil)
            sendMessage("response", success:true, result:"{}", requestId:request.id)
            
        default:
            let error="Unknown method:" + request.method;
            sendMessage("response", success:false, result:error, requestId:request.id)
        }
    }
    

    func sendMessage(type:String, success:Bool, result:String, requestId:Int = -1){
            let commandString = "recieveMessage('\(type)', \(success), '\(result)',\(requestId))"
            print("Sending JS request:",commandString)
            webView!.evaluateJavaScript(commandString, completionHandler: nil)
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
            print("Bluetooth is powered on")
        }
        else {
            print("Error:Bluetooth switched off or not initialized")
        }
    }
    
    func scanForPeripherals(options:AnyObject){
        if centralManager.state == CBCentralManagerState.PoweredOn{
            centralManager.scanForPeripheralsWithServices(nil, options: nil)
        }
    }
    
    //When we find a peripheral we add device to cache?
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
       
        let _nameOfDeviceFound = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        print("found:", _nameOfDeviceFound)
        print(advertisementData)
        
        //Todo Create a UI to choose the device instead of hardcoded.
        
        if _nameOfDeviceFound == WebBluetooth.deviceName{
            //Stop scanning and connect the peripheral
            self.centralManager.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
            centralManager.connectPeripheral(peripheral, options: nil)
        }
        else{
            print("Ignoring:",_nameOfDeviceFound)
        }
       
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
        
        //var bluetoothDevice = BluetoothDevice(peripheral,advertisementData,RSSI:RSSI)
        //self.sendMessage("found-device",success:true,result:device.toJSONString());
        
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
