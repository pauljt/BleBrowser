//
//  WebBluetooth.swift
//  BasicBrowser
//
//  Created by Paul Theriault on 10/01/2016.
//

import Foundation
import CoreBluetooth
import WebKit

open class WebBluetoothManager: NSObject, CBCentralManagerDelegate,WKScriptMessageHandler, PopUpPickerViewDelegate {

    /*
     * ========== Class constants ==========
     */
    enum ManagerRequests: String {
        case device, requestDevice
    }

    /*
     * ========== Properties ==========
     */
    let centralManager = CBCentralManager(delegate: nil, queue: nil)
    var devicePicker: PopUpPickerView!
    
    var BluetoothDeviceOption_filters: [CBUUID]?
    var BluetoothDeviceOption_optionalService: [CBUUID]?

    /*! @abstract The devices selected by the user for use by this manager. Keyed by the UUID provided by the system. */
    var devicesByInternalUUID = [UUID: BluetoothDevice]()

    /*! @abstract The devices selected by the user for use by this manager. Keyed by the UUID we create and pass to the web page. This seems to be for security purposes, and seems sensible. */
    var devicesByExternalUUID = [UUID: BluetoothDevice]()

    /*! @abstract The outstanding request for a device from the web page, if one is outstanding. Ony one may be outstanding at any one time and should be policed by a modal dialog box. TODO: how modal is the current solution? */
    var requestDeviceTransaction: WBTransaction? = nil
    var discoveredDevicesByInternalUUID = [UUID: BluetoothDevice]()

    var filters = [[String: AnyObject]]()
    var pickerNamesIds = [(name: String, id: UUID)]()

    /*
     * ========== Initialization ==========
     */
    override init(){
        super.init()
        self.centralManager.delegate = self
    }
    deinit {
        NSLog("WebBluetoothManager deinit")
        self.stopScanForPeripherals()
    }

    /*
     * ========== WKScriptMessageHandler ==========
     */
    open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        guard let trans = WBTransaction(withMessage: message) else {
            /* The transaction will have handled the error */
            return
        }
        NSLog("<-- new transaction #\(trans)")
        self.triage(transaction: trans)
    }

    /*
     * ========== CBCentralManagerDelegate ==========
     */
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("Bluetooth is \(central.state == CBManagerState.poweredOn ? "ON" : "OFF")")
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {

        guard self._peripheralIsIncludedByFilters(peripheral)
        else {
            return
        }
        
        self.discoveredDevicesByInternalUUID[peripheral.identifier] = BluetoothDevice(
            peripheral: peripheral, advertisementData: advertisementData,
            RSSI: RSSI, manager: self)

        self.updatePickerData()
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard
            let device = self.devicesByInternalUUID[peripheral.identifier]
        else {
            NSLog("Unexpected didConnect notification for \(peripheral.name) \(peripheral.identifier)")
            return
        }
        device.didConnect()
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard
            let device = self.devicesByInternalUUID[peripheral.identifier]
            else {
                NSLog("Unexpected didConnect notification for \(peripheral.name) \(peripheral.identifier)")
                return
        }
        device.didDisconnect(error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral) {
        NSLog("FAILED TO CONNECT PERIPHERAL UNHANDLED")
        
    }
    
    /*
     * ========== PopUpPickerViewDelegate ==========
     */
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerNamesIds[row].name
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelect numbers: [Int]) {

        guard
            numbers.count > 0,
            let index = Optional(numbers[0]),
            self.pickerNamesIds.count > index,
            let deviceId = Optional(self.pickerNamesIds[index].id),
            let device = self.discoveredDevicesByInternalUUID[deviceId]
        else {
            NSLog("Invalid device selection \(numbers), try again")
            self.devicePicker.showPicker()
            return
        }

        NSLog("Picker view did select \(deviceId)")
        self.requestDeviceTransaction?.resolveAsSuccess(withObject: device)
        self.deviceWasSelected(device)

    }
    public func pickerViewCancelled(_ pickerView: UIPickerView) {
        NSLog("User cancelled device selection.")
        self.requestDeviceTransaction?.resolveAsFailure(withMessage: "User cancelled")
    }
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerNamesIds.count
    }
    
    /*
     * ========== Private ==========
     */
    private func triage(transaction: WBTransaction){

        guard
            transaction.key.typeComponents.count > 0,
            let managerMessageType = ManagerRequests(
                rawValue: transaction.key.typeComponents[0])
        else {
            transaction.resolveAsFailure(withMessage: "Request type components not recognised \(transaction.key)")
            return
        }

        switch managerMessageType
        {
        case .requestDevice:
            guard transaction.key.typeComponents.count == 1
            else {
                transaction.resolveAsFailure(withMessage: "Invalid request type \(transaction.key)")
                break
            }
            guard let filters = transaction.messageData["filters"] as? [[String: AnyObject]]
            else {
                transaction.resolveAsFailure(withMessage: "Bad or no filters passed in data: \(transaction.messageData)")
                break
            }
            guard self.requestDeviceTransaction == nil
            else {
                transaction.resolveAsFailure(withMessage: "Previous device request is still in progress")
                break
            }
            self.requestDeviceTransaction = transaction
            self.scanForPeripherals(filters)
            transaction.addCompletionHandler {_, _ in
                self.stopScanForPeripherals()
                self.requestDeviceTransaction = nil
            }
            self.devicePicker.showPicker()

        case .device:

            guard let view = BluetoothDevice.DeviceTransactionView(transaction: transaction) else {
                transaction.resolveAsFailure(withMessage: "Bad device request")
                break
            }

            let devUUID = view.externalDeviceUUID
            guard let device = self.devicesByExternalUUID[devUUID]
            else {
                transaction.resolveAsFailure(withMessage: "No known device for device transaction \(transaction)")
                break
            }
            device.triage(transaction: transaction)
        }
    }

    private func deviceWasSelected(_ device: BluetoothDevice) {
        // TODO: think about whether overwriting any existing device is an issue.
        self.devicesByExternalUUID[device.deviceId] = device;
        self.devicesByInternalUUID[device.peripheral.identifier] = device;
    }

    func scanForPeripherals(_ filters:[[String: AnyObject]]) {

        let services = filters.reduce([String](), {
            (currReduction, nextValue) in
            if let nextServices = nextValue["services"] as? [String] {
                return currReduction + nextServices
            }
            return currReduction
        })

        //todo: determine if uppercase is the standard (bb-b uses uppercase UUID)
        let servicesCBUUIDq: [CBUUID?] = services.map {
            servStr -> CBUUID? in
            guard let uuid = UUID(uuidString: servStr.uppercased()) else {
                return nil
            }
            return CBUUID(nsuuid: uuid)
        }

        let servicesCBUUID = servicesCBUUIDq.filter{$0 != nil}.map{$0!}

        NSLog("Scanning for peripherals...")
        
        self.discoveredDevicesByInternalUUID.removeAll();
        self.filters = filters
        centralManager.scanForPeripherals(withServices: servicesCBUUID, options: nil)
    }
    func stopScanForPeripherals() {
        self.centralManager.stopScan()
        self.discoveredDevicesByInternalUUID.removeAll()
    }
    
    func updatePickerData(){
        self.pickerNamesIds.removeAll()
        for (id, device) in self.discoveredDevicesByInternalUUID {
            self.pickerNamesIds.append(
                (name: device.peripheral.name ?? "Unknown", id: id))
        }
        self.pickerNamesIds.sort(by: {$0.name < $1.name})
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
