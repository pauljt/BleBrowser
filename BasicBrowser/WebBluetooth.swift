//
//  WebBluetooth.swift
//  BleBrowser
//
//  Created by Paul Theriault on 7/03/2016.
//

import Foundation
import CoreBluetooth
import WebKit



open class BluetoothDevice: NSObject, CBPeripheralDelegate {
    var deviceId:String; //generated ID used instead of internal IOS name
    var peripheral:CBPeripheral
    var adData:BluetoothAdvertisingData
    var gattRequests:[CBUUID:JSRequest] = [CBUUID:JSRequest]()
    
    init(deviceId:String,peripheral:CBPeripheral,advertisementData:[String : AnyObject] = [String : AnyObject](),RSSI:NSNumber = 0){
        self.deviceId = deviceId
        self.peripheral = peripheral
        self.adData = BluetoothAdvertisingData(advertisementData:advertisementData,RSSI: RSSI)
        super.init()
        self.peripheral.delegate = self
    }
    
    func toJSON()->String?{
        let props:[String:Any] = [
            "id": deviceId,
            "name": peripheral.name,
            "adData": self.adData.toDict(),
            "deviceClass": 0,
            "vendorIDSource": 0,
            "vendorID": 0,
            "productID": 0,
            "productVersion": 0,
            "uuids": []
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: props,
                options: JSONSerialization.WritingOptions(rawValue: 0))
            return String(data: jsonData, encoding: String.Encoding.utf8)
        } catch let error {
            print("error converting to json: \(error)")
            return nil
        }
    }
    
    
    // connect services
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            print("found service:"+service.uuid.uuidString)
            if let matchedRequest = gattRequests[service.uuid]{
                matchedRequest.sendMessage("response", success:true, result:service.uuid.uuidString, requestId:matchedRequest.id)
            }
        }
    }
    
    // connect characteristics
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in (service.characteristics as [CBCharacteristic]!) {
            print("found char:" + char.uuid.uuidString)
            if let matchedRequest = gattRequests[char.uuid]{
                matchedRequest.sendMessage("response", success:true, result:"{}", requestId:matchedRequest.id)
            }
        }
    }
    
    
    // characteristic updates
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Characteristic Updated:",characteristic.uuid," ->",characteristic.value)

        if let matchedRequest = gattRequests[characteristic.uuid]{
            if let data = characteristic.value{
                let b64data = data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                matchedRequest.sendMessage("response", success:true, result:b64data, requestId:matchedRequest.id)
                return
            }else{
                matchedRequest.sendMessage("response", success:false, result:"{}", requestId:matchedRequest.id)
            }
        }
    }
    
    func getService(_ uuid:CBUUID)->CBService?{
        if(self.peripheral.services == nil){
            return nil
        }
        for service in peripheral.services!{
            if(service.uuid == uuid){
                return service
            }
        }
        return nil
    }
    
    func getCharacteristic(_ serviceUUID:CBUUID,uuid:CBUUID)->CBCharacteristic?{
        print(peripheral)
        if(self.peripheral.services == nil){
            return nil
        }
        var service:CBService? = nil
        for s in self.peripheral.services!{
            if(s.uuid == serviceUUID){
                service = s
            }
        }
        
        guard let chars = service?.characteristics else {
            return nil
        }
        
        for char in chars{
            if(char.uuid == uuid){
                return char
            }
        }
        return nil
    }
    
    
    func recieve(_ req:JSRequest){
        switch req.method{
        case "BluetoothRemoteGATTServer.getPrimaryService":
            let targetService:CBUUID = CBUUID(string:req.args[0])
            
            // check peripherals.services first to see if we already discovered services
            if (peripheral.services != nil ){
                if peripheral.services!.contains(where: {$0.uuid == targetService}) {
                    req.sendMessage("response", success:true, result:"{}", requestId:req.id)
                    return
                }else{
                    req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                    return
                }
            }
            
            print("Discovering service:"+targetService.uuidString)
            gattRequests[targetService] = req
            peripheral.discoverServices([targetService])
    
            case "BluetoothGATTService.getCharacteristic":
    
                let targetService:CBUUID = CBUUID(string:req.args[0])
                let targetChar:CBUUID = CBUUID(string:req.args[1])
                guard let service = getService(targetService) else {
                    req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                    return
                }
                
                if service.characteristics != nil{
                    for char in service.characteristics!{
                        if(char.uuid == targetChar){
                            req.sendMessage("response", success:true, result:"{}", requestId:req.id)
                            return
                        }else{
                            req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                            return
                        }
                    }
                }
                
                print("Discovering service:"+targetService.uuidString)
                gattRequests[targetChar] = req
                peripheral.discoverCharacteristics(nil, for: service)
            case "BluetoothGATTCharacteristic.readValue":
                let targetService:CBUUID = CBUUID(string:req.args[0])
                let targetChar:CBUUID = CBUUID(string:req.args[1])
                
                guard let char = getCharacteristic(targetService,uuid: targetChar) else{
                    req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                    return
                }
                
                gattRequests[char.uuid] = req
                self.peripheral.readValue(for: char)
 
        default:
            print("Unrecognized method requested")
        }
    }
}

class BluetoothAdvertisingData{
    var appearance:String
    var txPower:NSNumber
    var rssi:String
    var manufacturerData:String
    var serviceData:[String]
    
    init(advertisementData: [String : AnyObject] = [String : AnyObject](), RSSI: NSNumber = 0){
        self.appearance = "fakeappearance"
        self.txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber ?? 0)
        self.rssi=String(describing: RSSI)
        let data = advertisementData[CBAdvertisementDataManufacturerDataKey]
        self.manufacturerData = ""
        if data != nil{
            if let dataString = NSString(data: data as! Data, encoding: String.Encoding.utf8.rawValue) as? String {
                self.manufacturerData = dataString
            } else {
                print("Error parsing advertisement data: not a valid UTF-8 sequence")
            }
        }
        
        var uuids = [String]()
        if advertisementData["kCBAdvDataServiceUUIDs"] != nil {
            uuids = (advertisementData["kCBAdvDataServiceUUIDs"] as! [CBUUID]).map{$0.uuidString.lowercased()}
        }
        self.serviceData = uuids
    }
    
    func toDict()->[String:AnyObject]{
        let dict:[String:AnyObject] = [
            "appearance": self.appearance as AnyObject,
            "txPower": self.txPower,
            "rssi": self.rssi as AnyObject,
            "manufacturerData": self.manufacturerData as AnyObject,
            "serviceData": self.serviceData as AnyObject
        ]
        return dict
    }
    
}

