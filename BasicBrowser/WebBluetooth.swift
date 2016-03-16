//
//  WebBluetooth.swift
//  BleBrowser
//
//  Created by Paul Theriault on 7/03/2016.
//

import Foundation
import CoreBluetooth
import WebKit



public class BluetoothDevice: NSObject, CBPeripheralDelegate {
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
        let props:[String:AnyObject] = [
            "id": deviceId,
            "name": peripheral.name != nil ? peripheral.name! : NSNull(),
            "adData":self.adData.toDict(),
            "deviceClass": 0,
            "vendorIDSource": 0,
            "vendorID": 0,
            "productID": 0,
            "productVersion": 0,
            "uuids": []
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
    
    
    // connect services
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            print("found service:"+service.UUID.UUIDString)
            if let matchedRequest = gattRequests[service.UUID]{
                matchedRequest.sendMessage("response", success:true, result:service.UUID.UUIDString, requestId:matchedRequest.id)
            }
        }
    }
    
    // connect characteristics
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        for char in (service.characteristics as [CBCharacteristic]!) {
            print("found char:" + char.UUID.UUIDString)
            if let matchedRequest = gattRequests[char.UUID]{
                matchedRequest.sendMessage("response", success:true, result:"{}", requestId:matchedRequest.id)
            }
        }
    }
    
    
    // characteristic updates
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("Characteristic Updated:",characteristic.UUID," ->",characteristic.value)

        if let matchedRequest = gattRequests[characteristic.UUID]{
            if let data = characteristic.value{
                let b64data = data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
                matchedRequest.sendMessage("response", success:true, result:b64data, requestId:matchedRequest.id)
                return
            }else{
                matchedRequest.sendMessage("response", success:false, result:"{}", requestId:matchedRequest.id)
            }
        }
    }
    
    func getService(uuid:CBUUID)->CBService?{
        if(self.peripheral.services == nil){
            return nil
        }
        for service in peripheral.services!{
            if(service.UUID == uuid){
                return service
            }
        }
        return nil
    }
    
    func getCharacteristic(serviceUUID:CBUUID,uuid:CBUUID)->CBCharacteristic?{
        print(peripheral)
        if(self.peripheral.services == nil){
            return nil
        }
        var service:CBService? = nil
        for s in self.peripheral.services!{
            if(s.UUID == serviceUUID){
                service = s
            }
        }
        
        guard let chars = service?.characteristics else {
            return nil
        }
        
        for char in chars{
            if(char.UUID == uuid){
                return char
            }
        }
        return nil
    }
    
    
    func recieve(req:JSRequest){
        switch req.method{
        case "BluetoothRemoteGATTServer.getPrimaryService":
            let targetService:CBUUID = CBUUID(string:req.args[0])
            
            // check peripherals.services first to see if we already discovered services
            if (peripheral.services != nil ){
                if peripheral.services!.contains({$0.UUID == targetService}) {
                    req.sendMessage("response", success:true, result:"{}", requestId:req.id)
                    return
                }else{
                    req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                    return
                }
            }
            
            print("Discovering service:"+targetService.UUIDString)
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
                        if(char.UUID == targetChar){
                            req.sendMessage("response", success:true, result:"{}", requestId:req.id)
                            return
                        }else{
                            req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                            return
                        }
                    }
                }
                
                print("Discovering service:"+targetService.UUIDString)
                gattRequests[targetChar] = req
                peripheral.discoverCharacteristics(nil, forService: service)
            case "BluetoothGATTCharacteristic.readValue":
                let targetService:CBUUID = CBUUID(string:req.args[0])
                let targetChar:CBUUID = CBUUID(string:req.args[1])
                
                guard let char = getCharacteristic(targetService,uuid: targetChar) else{
                    req.sendMessage("response", success:false, result:"{}", requestId:req.id)
                    return
                }
                
                gattRequests[char.UUID] = req
                self.peripheral.readValueForCharacteristic(char)
 
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
        self.txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] ?? 0) as! NSNumber
        self.rssi=String(RSSI)
        let data = advertisementData[CBAdvertisementDataManufacturerDataKey]
        self.manufacturerData = ""
        if data != nil{
            if let dataString = NSString(data: data as! NSData, encoding: NSUTF8StringEncoding) as? String {
                self.manufacturerData = dataString
            } else {
                print("Error parsing advertisement data: not a valid UTF-8 sequence")
            }
        }
        
        var uuids = [String]()
        if advertisementData["kCBAdvDataServiceUUIDs"] != nil {
            uuids = (advertisementData["kCBAdvDataServiceUUIDs"] as! [CBUUID]).map{$0.UUIDString.lowercaseString}
        }
        self.serviceData = uuids
    }
    
    func toDict()->[String:AnyObject]{
        let dict:[String:AnyObject] = [
            "appearance": self.appearance,
            "txPower": self.txPower,
            "rssi": self.rssi,
            "manufacturerData": self.manufacturerData,
            "serviceData": self.serviceData
        ]
        return dict
    }
    
}

