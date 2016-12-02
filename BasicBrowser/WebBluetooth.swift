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
    var deviceId: String //generated ID used instead of internal IOS name
    var peripheral: CBPeripheral
    var adData: BluetoothAdvertisingData
    var gattRequests: [CBUUID: JSRequest] = [CBUUID:JSRequest]()
    var discoveringServices = false
    
    init(deviceId: String, peripheral: CBPeripheral, advertisementData:[String: AnyObject] = [String: AnyObject](), RSSI: NSNumber = 0){
        self.deviceId = deviceId
        self.peripheral = peripheral
        self.adData = BluetoothAdvertisingData(advertisementData:advertisementData,RSSI: RSSI)
        super.init()
        self.peripheral.delegate = self
    }

    func receive(_ req:JSRequest){
        NSLog("\(self.deviceId) handling req method: \(req.method)")

        switch req.method {
        case "BluetoothRemoteGATTServer.getPrimaryService":
            let targetService:CBUUID = CBUUID(string:req.args[0])
            print("device getPrimaryService: \(targetService)")

            // check peripherals.services first to see if we already discovered services
            if let pservs = peripheral.services {
                if pservs.contains(where: {$0.uuid == targetService}) {
                    req.sendMessage("response", success:true, result:"", requestId:req.id)
                    return
                }
                else {
                    req.sendMessage("response", success:false, result:"", requestId:req.id)
                    return
                }
            }

            print("Discovering service \(targetService.uuidString)")
            gattRequests[targetService] = req
            peripheral.discoverServices(nil)

        case "BluetoothGATTService.getCharacteristic":

            let targetService:CBUUID = CBUUID(string:req.args[0])
            let targetChar:CBUUID = CBUUID(string:req.args[1])
            guard let service = getService(targetService) else {
                let msg = "No such service \(targetService) for characteristic \(targetChar)"
                NSLog(msg)
                req.sendMessage("response", success:false, result:"'\(msg)'", requestId:req.id)
                return
            }

            if service.characteristics != nil{
                for char in service.characteristics!{
                    if(char.uuid == targetChar){
                        req.sendMessage("response", success:true, result:"{}", requestId:req.id)
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

        case "BluetoothGATTCharacteristic.writeValue":
            NSLog("Attempting to write characteristic")

            guard req.args.count >= 3 else {
                let msg = "Too few args to write a char val"
                NSLog(msg)
                req.sendMessage("response", success:false, result:"\"\(msg)\"", requestId:req.id)
                break
            }
            let targetService = CBUUID(string:req.args[0])
            let targetChar = CBUUID(string:req.args[1])

            guard let char = self.getCharacteristic(targetService, uuid: targetChar) else {
                let msg = "Failed to get characteristic value to write to"
                NSLog(msg)
                req.sendMessage("response", success:false, result:"\"\(msg)\"", requestId:req.id)
                break
            }

            guard let data = Data(base64Encoded:req.args[2]) else {
                let msg = "Failed to base64 decode data provided for device"
                NSLog("\(msg): \(req.args[2])")
                req.sendMessage("response", success:false, result:"\(msg)", requestId:req.id)
                break
            }

            NSLog("Writing value to peripheral")
            self.peripheral.writeValue(data, for: char, type: CBCharacteristicWriteType.withoutResponse)

            req.sendMessage("response", success:true, result:"", requestId:req.id)

        case "BluetoothGATTCharacteristic.startNotifications":
            req.sendMessage("response", success: true, result: "{}", requestId:req.id)

        default:
            print("Unrecognized device method.")
        }
    }
    
    func toJSON()->String?{
        let props:[String:Any] = [
            "id": deviceId,
            "name": (peripheral.name ?? NSNull()) as Any,
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

    func startDiscoveringServices() {
        peripheral.discoverServices(nil)
        discoveringServices = true
    }
    
    
    //
    // ========== CBPeripheralDelegate ==========
    //
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        discoveringServices = false
        if let err = error {
            NSLog("error discovering services: \(err)")
            return
        }
        for service in peripheral.services! {
            NSLog("found service: \(service.uuid.uuidString)")
            if let matchedRequest = gattRequests[service.uuid]{
                matchedRequest.sendMessage("response", success:true, result:service.uuid.uuidString, requestId:matchedRequest.id)
            }
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let err = error {
            NSLog("Error in peripheral didDiscoverChars: \(err)")
            return
        }
        for char in (service.characteristics as [CBCharacteristic]!) {
            print("found char:" + char.uuid.uuidString)
            if let matchedRequest = self.gattRequests[char.uuid]{
                matchedRequest.sendMessage("response", success:true, result:"{}", requestId:matchedRequest.id)
            }
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Characteristic Updated: \(characteristic.uuid) -> \(characteristic.value)")

        if let err = error {
            print("Error in peripheral didUpdateValueFor: \(err)")
            return
        }

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

    //
    // ========== INTERNAL ==========
    //
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
                break
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

