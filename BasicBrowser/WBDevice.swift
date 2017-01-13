//
//  WebBluetooth.swift
//  BleBrowser
//
//  Created by Paul Theriault on 7/03/2016.
//

import Foundation
import CoreBluetooth
import WebKit


open class WBDevice: NSObject, Jsonifiable, CBPeripheralDelegate {
    // MARK: - Embedded types
    enum DeviceRequests: String {
        case connectGATT, disconnectGATT,  getPrimaryService,
        getCharacteristic, readCharacteristicValue, startNotifications,
        writeCharacteristicValue
    }
    // MARK: Transaction views
    class DeviceTransactionView: WBTransaction.View {
        let externalDeviceUUID: UUID

        override init?(transaction: WBTransaction) {
            guard
                let uuidstr = transaction.messageData["deviceId"] as? String,
                let uuid = UUID(uuidString: uuidstr)
                else {
                    return nil
            }
            self.externalDeviceUUID = uuid
            super.init(transaction: transaction)
        }
    }
    class ServiceTransactionView: DeviceTransactionView {

        let serviceUUID: CBUUID

        override init?(transaction: WBTransaction) {
            guard
                let pservStr = transaction.messageData["serviceUUID"] as? String,
                let pservUUID = UUID(uuidString: pservStr)
                else {
                    return nil
            }
            self.serviceUUID = CBUUID(nsuuid: pservUUID)
            super.init(transaction: transaction)
        }

        func resolveUnknownService() {
            self.transaction.resolveAsFailure(withMessage: "Service \(self.serviceUUID.uuidString) not known on device")
        }
    }
    class CharacteristicView: ServiceTransactionView {

        let characteristicUUID: CBUUID

        override init?(transaction: WBTransaction) {
            guard
                let charStr = transaction.messageData["characteristicUUID"] as? String,
                let charUUID = UUID(uuidString: charStr)
                else {
                    return nil
            }
            self.characteristicUUID = CBUUID(nsuuid: charUUID)
            super.init(transaction: transaction)
        }
        func resolveUnknownCharacteristic() {
            self.transaction.resolveAsFailure(withMessage: "Characteristic \(self.characteristicUUID.uuidString) not known for service \(self.serviceUUID.uuidString) on device")
        }
    }
    class WriteCharacteristicView: CharacteristicView {

        let data: Data

        override init?(transaction: WBTransaction) {
            guard
                let dstr = transaction.messageData["value"] as? String,
                let data = Data(base64Encoded: dstr)
            else {
                return nil
            }
            self.data = data
            super.init(transaction: transaction)
        }
    }
    struct CharacteristicTransactionKey: Hashable {
        let serviceUUID: CBUUID
        let characteristicUUID: CBUUID

        var hashValue: Int {
            return self.serviceUUID.hashValue ^ self.characteristicUUID.hashValue
        }
        static func == (left: CharacteristicTransactionKey, right: CharacteristicTransactionKey) -> Bool {
            return left.serviceUUID == right.serviceUUID && left.characteristicUUID == right.characteristicUUID
        }
    }

    // MARK: - Properties
    let debug = true
    var deviceId = UUID() // generated ID used instead of internal iOS name
    var peripheral: CBPeripheral
    var adData: BluetoothAdvertisingData

    weak var manager: WBManager?

    /*! @abstract The view should be set when the device is selected by a particular web view. */
    weak var view: WKWebView? = nil

    /*! @abstract The current transactions to connect to this device. There can be multiple outstanding at any one time and they are all resolved together. */
    var connectTransactions = [WBTransaction]()
    var disconnectTransactions = [WBTransaction]()
    var getPrimaryServiceTM = WBTransactionManager<CBUUID>()
    var getCharacteristicTM = WBTransactionManager<CharacteristicTransactionKey>()
    var readCharacteristicTM = WBTransactionManager<CharacteristicTransactionKey>()

    // MARK: - Constructor
    init(peripheral: CBPeripheral, advertisementData: [String: Any] = [:], RSSI: NSNumber = 0, manager: WBManager) {
        self.peripheral = peripheral
        self.adData = BluetoothAdvertisingData(advertisementData:advertisementData,RSSI: RSSI)
        self.manager = manager
        super.init()
        self.peripheral.delegate = self
    }

    // MARK: - API
    func clearState() {
        self.manager?.centralManager.cancelPeripheralConnection(self.peripheral)
        for var ta in [self.connectTransactions, self.disconnectTransactions] {
            for trans in ta {
                trans.abandon()
            }
            ta.removeAll()
        }
        self.getPrimaryServiceTM.abandonAll()
        self.getCharacteristicTM.abandonAll()
        self.readCharacteristicTM.abandonAll()
    }
    func didConnect() {
        self.connectTransactions.forEach{$0.resolveAsSuccess()}
    }
    func didFailToConnect() {
        self.connectTransactions.forEach{$0.resolveAsFailure(withMessage: "Unable to connect to device")}
    }
    func didDisconnect(error: Error?) {
        self.connectTransactions.forEach {$0.resolveAsFailure(withMessage: "Connection was cancelled or prematurely disconnected. Extra error info: \(error as? String ?? "<none>")")}
        if let err = error {
            NSLog("Spontaneous device disconnect. \(err)")
            if self.disconnectTransactions.count > 0 {
                self.disconnectTransactions.forEach {$0.resolveAsFailure(withMessage: "\(err)")}
            }
            else {
                /* Don't lower case the deviceId string because we rely on the web page not to touch it. */
                let commandString = "window.receiveDeviceDisconnectEvent(\(self.deviceId.uuidString.jsonify()));\n"
                NSLog("--> device disconnect execute js: \"\(commandString)\"")
                if let wv = self.view {
                    wv.evaluateJavaScript(commandString, completionHandler: {
                        _, error in
                        if let err = error {
                            NSLog("Error evaluating \(commandString): \(err)")
                        }})
                }
            }
            return
        }
        self.disconnectTransactions.forEach {$0.resolveAsSuccess()}
    }

    func triage(transaction: WBTransaction) {

        let tc = transaction.key.typeComponents
        guard
            tc.count > 1,
            let deviceMessageType = DeviceRequests(rawValue: tc[1])
        else {
            transaction.resolveAsFailure(withMessage: "Unknown request type \(tc.joined(separator: ":"))")
            return
        }

        switch deviceMessageType {
        case .connectGATT:
            guard let man = self.manager else {
                transaction.resolveAsFailure(withMessage: "Failed due to internal inconsistency likely related to a recent page navigation (device's manager was released)")
                return
            }

            if self.debug {
                NSLog("Connecting to GATT on device \(self)")
            }

            man.centralManager.connect(self.peripheral)
            // async, so save transaction to resolve when connected
            transaction.addCompletionHandler({
                transaction, _ in
                if let ind = self.connectTransactions.index(of: transaction) {
                    self.connectTransactions.remove(at: ind)
                }
            })
            self.connectTransactions.append(transaction)

        case .disconnectGATT:
            guard let man = self.manager else {
                transaction.resolveAsFailure(withMessage: "Failed due to internal inconsistency likely related to a recent page navigation (device's manager was released)")
                return
            }
            man.centralManager.cancelPeripheralConnection(
                self.peripheral)
            transaction.addCompletionHandler({
                transaction, _ in
                if let ind = self.disconnectTransactions.index(of: transaction) {
                    self.disconnectTransactions.remove(at: ind)
                }
            })
            self.disconnectTransactions.append(transaction)

        case .getPrimaryService:

            guard
                let tview = ServiceTransactionView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid getPrimaryService request")
                return
            }

            // check peripherals.services first to see if we already discovered services
            if self.peripheral.services != nil {
                if self.hasService(withUUID: tview.serviceUUID) {
                    transaction.resolveAsSuccess()
                }
                else {
                    tview.resolveUnknownService()
                }
                return
            }

            self.getPrimaryServiceTM.addTransaction(transaction, atPath: tview.serviceUUID)
            NSLog("Starting discovering for service \(tview.serviceUUID)")
            self.peripheral.discoverServices(nil)

        case .getCharacteristic:

            guard
                let view = CharacteristicView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid message")
                break
            }

            guard let service = self.getService(withUUID: view.serviceUUID)
            else {
                view.resolveUnknownService()
                return
            }

            if let chars = service.characteristics {
                // Have already discovered characteristics for this device.
                if chars.contains(where: {$0.uuid == view.characteristicUUID}) {
                    transaction.resolveAsSuccess()
                } else {
                    view.resolveUnknownCharacteristic()
                }
                break
            }

            self.getCharacteristicTM.addTransaction(transaction, atPath: CharacteristicTransactionKey(serviceUUID: service.uuid, characteristicUUID: view.characteristicUUID))
            NSLog("Start discovering characteristics for service \(service.uuid)")
            self.peripheral.discoverCharacteristics(nil, for: service)

        case .readCharacteristicValue:

            guard
                let view = CharacteristicView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid message")
                break
            }
            guard let service = self.getService(withUUID: view.serviceUUID) else {
                view.resolveUnknownService()
                break
            }
            guard let chars = service.characteristics else {
                transaction.resolveAsFailure(withMessage: "Characteristics have not yet been retrieved for service \(service.uuid.uuidString)")
                break
            }
            guard let char = chars.first(where: {$0.uuid == view.characteristicUUID}) else {
                view.resolveUnknownCharacteristic()
                break
            }

            self.readCharacteristicTM.addTransaction(transaction, atPath: CharacteristicTransactionKey(serviceUUID: view.serviceUUID, characteristicUUID: view.characteristicUUID))
            self.peripheral.readValue(for: char)

        case .writeCharacteristicValue:

            guard
                let view = WriteCharacteristicView(transaction: transaction)
            else {
                transaction.resolveAsFailure(withMessage: "Invalid write characteristic message")
                break
            }

            guard
                let char = self.getCharacteristic(view.serviceUUID, uuid: view.characteristicUUID)
            else {
                view.resolveUnknownCharacteristic()
                break
            }

            NSLog("Writing value \(String(data: view.data, encoding: String.Encoding.utf8)) to peripheral")
            self.peripheral.writeValue(view.data, for: char, type: CBCharacteristicWriteType.withoutResponse)
            transaction.resolveAsSuccess()

        case .startNotifications:

            guard let view = CharacteristicView(transaction: transaction) else {
                transaction.resolveAsFailure(withMessage: "Invalid start notifications message")
                break
            }

            guard let char = self.getCharacteristic(view.serviceUUID, uuid: view.characteristicUUID) else {
                view.resolveUnknownCharacteristic()
                break
            }
            NSLog("Starting notifications for characteristic \(view.characteristicUUID.uuidString) on device \(self.peripheral.name)")

            self.peripheral.setNotifyValue(true, for: char)
            transaction.resolveAsSuccess()
        }
    }
    
    func jsonify() -> String {
        let props: [String: Any] = [
            "id": self.deviceId.uuidString,
            "name": (self.peripheral.name ?? NSNull()) as Any,
            "adData": self.adData.toDict(),
            "deviceClass": 0,
            "vendorIDSource": 0,
            "vendorID": 0,
            "productID": 0,
            "productVersion": 0,
            "uuids": []
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: props)
            return String(data: jsonData, encoding: String.Encoding.utf8)!
        } catch let error {
            assert(false, "error converting to json: \(error)")
            return ""
        }
    }
    

    // MARK: - CBPeripheralDelegate
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        var resolve: (WBTransaction) -> Void
        if let err = error {
            resolve = {$0.resolveAsFailure(withMessage: "An error occurred discovering services for the device: \(err)")}
        }
        else {
            let cbServices = self.peripheral.services!
            let serviceUUIDs = cbServices.map{$0.uuid}
            let services = Set(serviceUUIDs)

            resolve = {
                let tview = ServiceTransactionView(transaction: $0)!
                if services.contains(tview.serviceUUID) {
                    $0.resolveAsSuccess()
                }
                else {
                    tview.resolveUnknownService()
                }
            }
        }

        /* All outstanding requests for a primary service can be resolved. */
        self.getPrimaryServiceTM.apply(resolve)
    }

    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        self.getCharacteristicTM.apply(
            {
                let cview = CharacteristicView(transaction: $0)!
                guard service.characteristics?.first(where: {$0.uuid == cview.characteristicUUID}) != nil else {
                    cview.resolveUnknownCharacteristic()
                    return
                }
                $0.resolveAsSuccess()
            },
            iff: {CharacteristicView(transaction: $0)!.serviceUUID == service.uuid})
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error {
            NSLog("Error \(err) adding notifications to device \(peripheral.name) for characteristic \(characteristic.uuid.uuidString)")
        } else {
            NSLog("Notifications enabled on device \(peripheral.name) for characteristic \(characteristic.uuid.uuidString)")
        }
    }

    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        NSLog("Characteristic Updated: \(characteristic.uuid.uuidString) -> \(characteristic.value)")

        if self.readCharacteristicTM.transactions.count > 0 {
            // We have read transactions outstanding, which means that this is a response after a read request, so complete those transactions.
            self.readCharacteristicTM.apply(
                {
                    if let err = error {
                        $0.resolveAsFailure(withMessage: "Error reading characteristic: \(err.localizedDescription)")
                        return
                    }
                    $0.resolveAsSuccess(withObject: characteristic.value!)
            },
                iff: {
                    let cview = CharacteristicView(transaction: $0)!
                    return cview.serviceUUID == characteristic.service.uuid && cview.characteristicUUID == characteristic.uuid
            })
        }
        // If we're doing notifications on the characteristic send them up.
        if characteristic.isNotifying {
            if let wv = self.view {
                wv.evaluateJavaScript(
                    "receiveCharacteristicValueNotification(" +
                    "\(characteristic.uuid.uuidString.lowercased().jsonify()), " +
                    "\(characteristic.value!.jsonify())" +
                    ")")

            }
        }
    }

    // MARK: - Private
    private func getService(withUUID uuid: CBUUID) -> CBService?{
        guard
            let pservs = self.peripheral.services,
            let ind = pservs.index(where: {$0.uuid == uuid})
        else {
            return nil
        }
        return pservs[ind]
    }
    private func hasService(withUUID uuid: CBUUID) -> Bool {
        return self.getService(withUUID: uuid) != nil
    }
    
    private func getCharacteristic(_ serviceUUID:CBUUID, uuid:CBUUID) -> CBCharacteristic? {
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

/*!
 *  @class BluetoothAdvertisingData
 *
 *  @discussion This encapsulates the data required for a BluetoothAdvertisingEvent as per https://webbluetoothcg.github.io/web-bluetooth/#advertising-events .
 */
class BluetoothAdvertisingData{
    var appearance:String
    var txPower:NSNumber
    var rssi: String
    var manufacturerData:String
    var serviceData:[String]
    
    init(advertisementData: [String: Any], RSSI: NSNumber){
        self.appearance = "fakeappearance"
        self.txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber ?? 0)
        self.rssi = String(describing: RSSI)
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
