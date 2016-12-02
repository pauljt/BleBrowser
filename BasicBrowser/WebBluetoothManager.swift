//
//  WebBluetooth.swift
//  BasicBrowser
//
//  Created by Paul Theriault on 10/01/2016.
//

import Foundation
import CoreBluetooth
import WebKit

open class WebBluetoothManager: NSObject, CBCentralManagerDelegate, WKScriptMessageHandler, PopUpPickerViewDelegate {
    
    override init(){
        super.init()
        centralManager.delegate = self
    }

    // BLE
    let centralManager = CBCentralManager(delegate: nil, queue: nil)
    var devicePicker:PopUpPickerView!
    
    var BluetoothDeviceOption_filters:[CBUUID]?
    var BluetoothDeviceOption_optionalService:[CBUUID]?
    
    // Stores references to devices while scanning. Key is the system provided UUID (peripheral.id)
    var foundDevices:[String:BluetoothDevice] = [String:BluetoothDevice]()
    var deviceRequest:JSRequest? //stores the last requestID for device requests (i.e. subsequent request replace unfinished requests)
    var connectionRequest:JSRequest? // stores last conncetion request, to resolve when connected/disconnected
    var disconnectionRequest:JSRequest? // stores last conncetion request, to resolve when connected/disconnected


    // Allowed Devices Map
    // See https://webbluetoothcg.github.io/web-bluetooth/#per-origin-device-properties
    // Stores a dictionary for each origin which holds a mappping between Device ID and the actual BluetoothDevice
    // For example, if a user grants access for https://example.com  would be something like:
    //    allowedDevices["https://example.com"]?[NSUUID().UUIDString] = new BluetoothDevice(peripheral)
    var allowedDevices:[String:[String:BluetoothDevice]] = [String:[String:BluetoothDevice]]()
    var filters = [[String: AnyObject]]()
    var pickerNamesIds = [(name: String, id: String)]()
    
    //
    // ========== WKScriptMessageHandler ==========
    //
    open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage){

        // TODO don't really want to crash if these aren't OK.
        let messageBody = message.body as! NSDictionary
        let callbackID:Int =  messageBody["callbackID"] as! Int
        let type = messageBody["type"] as! String
        let data = messageBody["data"] as! [String:AnyObject]

        //todo add safety
        let req = JSRequest(id: callbackID,type:type,data:data,webView:message.webView!);
        print("<-- #\(callbackID) to dispatch \(type) with data:\(data)")
        self.processRequest(req)
    }
    
    //
    // ==================== CBCentralManagerDelegate ====================
    //
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            print("Bluetooth is powered on")
        }
        else {
            print("Error:Bluetooth switched off or not initialized")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        NSLog("discovered device: \(peripheral)")

        if !self._peripheralIsIncludedByFilters(peripheral) {
            NSLog("Device is excluded by filters")
            return
        }

        let deviceId = UUID().uuidString;
        self.foundDevices[peripheral.identifier.uuidString] = BluetoothDevice(deviceId: deviceId, peripheral: peripheral,
            advertisementData: advertisementData as [String : AnyObject],
            RSSI: RSSI)
        self.updatePickerData()
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected")
        if(connectionRequest != nil){
            connectionRequest!.sendMessage("response", success:true, result:"{}", requestId:connectionRequest!.id)
            connectionRequest = nil
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral) {
        print("Failed to connect")
        connectionRequest!.sendMessage("response", success:false, result:"'Failed to connect'", requestId:connectionRequest!.id)
        connectionRequest = nil
        
    }
    
    //
    // ========== PopUpPickerViewDelegate ==========
    //
    
    // The data to return for the row and component (column) that's being passed in
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerNamesIds[row].name
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelect numbers: [Int]) {
        
        if(self.pickerNamesIds.count < 1){
            NSLog("No devices to select!")
            return
        }
        let deviceId = self.pickerNamesIds[numbers[0]].id
        self.centralManager.stopScan()

        // Should not be nil since the picker view display is in response to
        // a message.
        let req = self.deviceRequest!
        self.deviceRequest = nil
        
        if self.foundDevices[deviceId] == nil {
            NSLog("deviceId \(deviceId) not in foundDevices")
            return
        }
        let device = self.foundDevices[deviceId]!
        let deviceJSON = device.toJSON()!
        
        if self.allowedDevices[req.origin] == nil {
            self.allowedDevices[req.origin] = [String:BluetoothDevice]()
        }
        // add device to allowed list, and resolve requestDevice promise
        self.allowedDevices[req.origin]![device.deviceId] = device
        req.sendMessage("response", success:true, result:deviceJSON, requestId:req.id)
    }
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerNamesIds.count
    }
    
    //
    // ========== Private ==========
    //
    func processRequest(_ req:JSRequest){
        switch req.type {
        case "bluetooth:requestDevice":
            guard let data = req.data["filters"] as? [[String: AnyObject]] else {
                req.sendMessage("response", success:false, result:"Bad filters passed: \(req.data)", requestId:req.id)
                break
            }
            self.scanForPeripherals(data)
            self.deviceRequest = req
            self.devicePicker.showPicker()
            
        case "bluetooth:deviceMessage":
            print("DeviceMessage for \(req.deviceId)")
            print("Calling \(req.method) with \(req.args)")
            print(req.args)
            
            if let device = allowedDevices[req.origin]?[req.deviceId]{
                // connecting/disconnecting GATT server has to be handled by the manager
                if(req.method == "BluetoothRemoteGATTServer.connect"){
                    centralManager.connect(device.peripheral,options: nil)
                    connectionRequest = req //resolved when connected
                }else if (req.method == "BluetoothRemoteGATTServer.disconnect"){
                    centralManager.cancelPeripheralConnection(device.peripheral)
                    disconnectionRequest = req //resolved when connected
                }else{
                    device.receive(req)
                }
            }
            else{
                req.sendMessage("response", success:false, result:"\"Device not found\"", requestId:req.id)
            }
        default:
            let error="\"Unknown method: \(req.type)\"";
            req.sendMessage("response", success:false, result:error, requestId:req.id)
        }
    }
    
    func scanForPeripherals(_ filters:[[String: AnyObject]]) {
        
        NSLog("Scanning for peripherals with filters \(filters)")

        let services = filters.reduce([String](), {
            (currReduction, nextValue) in
            if let nextServices = nextValue["services"] as? [String] {
                return currReduction + nextServices
            }
            return currReduction
        })

        let servicesCBUUID:[CBUUID]
        
        //todo validate CBUUID (js does this already but security should be here since
        //messageHandler can be called directly.
        // (if the string is invalid, it causes app to crash with NSexception)
        
        //todo: determine if uppercase is the standard (bb-b uses uppercase UUID)
        servicesCBUUID = services.map { CBUUID(string:$0.uppercased()) }
        
        self.foundDevices.removeAll();
        self.filters = filters
        centralManager.scanForPeripherals(withServices: servicesCBUUID, options: nil)
    }
    
    func updatePickerData(){
        self.pickerNamesIds.removeAll()
        for (id, device) in self.foundDevices {
            self.pickerNamesIds.append(
                (name: device.peripheral.name ?? "Unknown", id: id))
        }
        self.pickerNamesIds.sort(by: <)
        self.devicePicker.updatePicker()
    }
    
    func transformArguments(_ args: [AnyObject]) -> [AnyObject?] {
        assert(false, "not expecting transformArguments to get called.")
        return args.map { arg in
            if arg is NSNull {
                return nil
            } else {
                return arg
            }
        }
    }

    func _peripheralIsIncludedByFilters(_ peripheral: CBPeripheral) -> Bool {
        for filter in self.filters {
            if let pname = peripheral.name {
                if let namePrefix = filter["namePrefix"] as? String {
                    if pname.hasPrefix(namePrefix) { return true }
                }
            }
        }
        return false
    }
}
