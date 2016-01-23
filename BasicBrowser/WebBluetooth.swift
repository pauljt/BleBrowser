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
    //native objects
    var peripheral:CBPeripheral?
    var advertisementData:[String : AnyObject]
    
    //properties for web
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
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        
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




class WebBluetooth: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, WKScriptMessageHandler, PopUpPickerViewDelegate {
    
    override init(){
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    //too remove - only connect to bb-8 for now
    static let deviceName = "BB-7687"
    
    var deviceNames: [String] = [String]()
    
    
    // BLE
    var centralManager:CBCentralManager!
    //var peripheral:CBPeripheral!

    //stores the webView we are linked to
    var webView:WKWebView!
    var devicePicker:PopUpPickerView!

    var BluetoothDeviceOption_filters:[CBUUID]?
    var BluetoothDeviceOption_optionalService:[CBUUID]?
    
    //WebBluetooth vars
    var deviceCache:[BluetoothDevice] = [BluetoothDevice]()
    var connectedDevice:BluetoothDevice?
    
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
            
            let servicesCBUUID:[CBUUID]
            
            //todo validate CBUUID (js does this already but security should be here since 
            //messageHandler can be called directly? Or can it?
            // (if the string is invalid, it causes app to crash with NSexception)
            
            //todo: determine if uppercase is the standard (bb-b uses uppercase UUID)
            servicesCBUUID = services.map {return CBUUID(string:$0.uppercaseString)}
            centralManager.scanForPeripheralsWithServices(servicesCBUUID, options: nil)
            sendMessage("response", success:true, result:"{}", requestId:request.id)
            devicePicker.showPicker()
            
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
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
       
        let _nameOfDeviceFound = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        print("found:", _nameOfDeviceFound)
        print(advertisementData)
        
        deviceNames.append(_nameOfDeviceFound!);
        deviceCache.append(BluetoothDevice(peripheral: peripheral,advertisementData: advertisementData,RSSI: RSSI))
        devicePicker.updatePicker()
        
        
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
    
    
    //UIPickerView protocols
    // The number of columns of data
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return deviceNames.count
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return deviceNames[row]
    }
    
    
    func pickerView(pickerView: UIPickerView, didSelect numbers: [Int]) {
        connectedDevice = deviceCache[numbers[0]]
        centralManager.stopScan()
        
        //todo get rid of all the unwrapping!
        self.connectedDevice!.peripheral!.delegate = self
        centralManager.connectPeripheral(connectedDevice!.peripheral!, options: nil)
        
        self.sendMessage("found-device",success:true,result:(connectedDevice?.toJSON())!);

        
    }
    
}
