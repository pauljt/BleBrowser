// adapted from chrome app polyfill https://github.com/WebBluetoothCG/chrome-app-polyfill

(function () {
  "use strict";

  function canonicalUUID(uuidAlias) {
    uuidAlias >>>= 0;  // Make sure the number is positive and 32 bits.
    var strAlias = "0000000" + uuidAlias.toString(16);
    strAlias = strAlias.substr(-8);
    return strAlias + "-0000-1000-8000-00805f9b34fb"
  }

  if (navigator.bluetooth) {
    // navigator.bluetooth already exists; not polyfilling.
    if (!window.BluetoothUUID) {
      window.BluetoothUUID = {};
    }
    if (!window.BluetoothUUID.canonicalUUID) {
      window.BluetoothUUID.canonicalUUID = canonicalUUID;
    }
    return;
  }

  var uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

  // https://webbluetoothcg.github.io/web-bluetooth/ interface
  function BluetoothDevice(nativeBluetoothDevice) {
    console.log("got device:", nativeBluetoothDevice)
    this._id = nativeBluetoothDevice.id;
    this._name = nativeBluetoothDevice.name;

    this._adData = {};
    if (nativeBluetoothDevice.adData) {
      this._adData.appearance = nativeBluetoothDevice.adData.appearance || "";
      this._adData.txPower = nativeBluetoothDevice.adData.txPower || 0;
      this._adData.rssi = nativeBluetoothDevice.adData.rssi || 0;
      this._adData.manufacturerData = nativeBluetoothDevice.adData.manufacturerData || [];
      this._adData.serviceData = nativeBluetoothDevice.adData.serviceData || [];
    }

    this._deviceClass = nativeBluetoothDevice.deviceClass || 0;
    this._vendorIdSource = nativeBluetoothDevice.vendorIdSource || "bluetooth";
    this._vendorId = nativeBluetoothDevice.vendorId || 0;
    this._productId = nativeBluetoothDevice.productId || 0;
    this._productVersion = nativeBluetoothDevice.productVersion || 0;
    this._paired = nativeBluetoothDevice.paired;
    this._connected = nativeBluetoothDevice.connected;
    this._gattServer = nativeBluetoothDevice._gattServer;
    this._uuids = nativeBluetoothDevice.uuids;
  };

  window.BluetoothDevice = BluetoothDevice;

  BluetoothDevice.prototype = {

    get id() {
      return this._id;
    },
    get name() {
      return this._name;
    },
    get adData() {
      return this._adData;
    },
    get deviceClass() {
      return this._deviceClass;
    },
    get vendorIdSource() {
      return this._vendorIdSource;
    },
    get vendorId() {
      return this._vendorId;
    },
    get productId() {
      return this._productId;
    },
    get productVersion() {
      return this._productVersion;
    },
    get paired() {
      return this._paired;
    },
    get connected() {
      return this._connected;
    },
    get gattServer() {
      return this._gattServer;
    },
    get uuids() {
      return this._uuids;
    },

    connectGatt: function () {
      console.log("not implemented")
    },

    toString: function () {
      return self._id;
    }
  };


  function BluetoothGattRemoteServer(webBluetoothDevice) {
    this._device = webBluetoothDevice;
    this._connected = false;
  };
  window.BluetoothGattRemoteServer = BluetoothGattRemoteServer;

  BluetoothGattRemoteServer.prototype = {
    get device() {
      return this._device;
    },
    get connected() {
      return this._connected;
    },

    getPrimaryService: function (characteristicUuids) {
      var self = this;
    },

    getPrimaryServices: function (characteristicUuids) {

    }
  };


  window.recieveMessage = recieveMessage;

  navigator.bluetooth = {};

  window.BluetoothUUID = {};

  window.BluetoothUUID.canonicalUUID = canonicalUUID;

  function ResolveUUIDName(tableName) {
    var table = window.BluetoothUUID[tableName];
    return function (name) {
      if (typeof name === "number") {
        return canonicalUUID(name);
      } else if (uuidRegex.test(name.toLowerCase())) {
        //note native part converts to uppercase since IOS needs that?
        return name.toLowerCase();
      } else if (table.hasOwnProperty(name)) {
        return table[name];
      } else {
        throw new Error('SyntaxError: "' + name + '" is not a known ' + tableName + ' name.');
      }
    }
  }

  window.BluetoothUUID.service = {
    alert_notification: canonicalUUID(0x1811),
    automation_io: canonicalUUID(0x1815),
    battery_service: canonicalUUID(0x180F),
    blood_pressure: canonicalUUID(0x1810),
    body_composition: canonicalUUID(0x181B),
    bond_management: canonicalUUID(0x181E),
    continuous_glucose_monitoring: canonicalUUID(0x181F),
    current_time: canonicalUUID(0x1805),
    cycling_power: canonicalUUID(0x1818),
    cycling_speed_and_cadence: canonicalUUID(0x1816),
    device_information: canonicalUUID(0x180A),
    environmental_sensing: canonicalUUID(0x181A),
    generic_access: canonicalUUID(0x1800),
    generic_attribute: canonicalUUID(0x1801),
    glucose: canonicalUUID(0x1808),
    health_thermometer: canonicalUUID(0x1809),
    heart_rate: canonicalUUID(0x180D),
    human_interface_device: canonicalUUID(0x1812),
    immediate_alert: canonicalUUID(0x1802),
    indoor_positioning: canonicalUUID(0x1821),
    internet_protocol_support: canonicalUUID(0x1820),
    link_loss: canonicalUUID(0x1803),
    location_and_navigation: canonicalUUID(0x1819),
    next_dst_change: canonicalUUID(0x1807),
    phone_alert_status: canonicalUUID(0x180E),
    pulse_oximeter: canonicalUUID(0x1822),
    reference_time_update: canonicalUUID(0x1806),
    running_speed_and_cadence: canonicalUUID(0x1814),
    scan_parameters: canonicalUUID(0x1813),
    tx_power: canonicalUUID(0x1804),
    user_data: canonicalUUID(0x181C),
    weight_scale: canonicalUUID(0x181D)
  }


  window.BluetoothUUID.characteristic = {
    "aerobic_heart_rate_lower_limit": canonicalUUID(0x2A7E),
    "aerobic_heart_rate_upper_limit": canonicalUUID(0x2A84),
    "aerobic_threshold": canonicalUUID(0x2A7F),
    "age": canonicalUUID(0x2A80),
    "aggregate": canonicalUUID(0x2A5A),
    "alert_category_id": canonicalUUID(0x2A43),
    "alert_category_id_bit_mask": canonicalUUID(0x2A42),
    "alert_level": canonicalUUID(0x2A06),
    "alert_notification_control_point": canonicalUUID(0x2A44),
    "alert_status": canonicalUUID(0x2A3F),
    "altitude": canonicalUUID(0x2AB3),
    "anaerobic_heart_rate_lower_limit": canonicalUUID(0x2A81),
    "anaerobic_heart_rate_upper_limit": canonicalUUID(0x2A82),
    "anaerobic_threshold": canonicalUUID(0x2A83),
    "analog": canonicalUUID(0x2A58),
    "apparent_wind_direction": canonicalUUID(0x2A73),
    "apparent_wind_speed": canonicalUUID(0x2A72),
    "gap.appearance": canonicalUUID(0x2A01),
    "barometric_pressure_trend": canonicalUUID(0x2AA3),
    "battery_level": canonicalUUID(0x2A19),
    "blood_pressure_feature": canonicalUUID(0x2A49),
    "blood_pressure_measurement": canonicalUUID(0x2A35),
    "body_composition_feature": canonicalUUID(0x2A9B),
    "body_composition_measurement": canonicalUUID(0x2A9C),
    "body_sensor_location": canonicalUUID(0x2A38),
    "bond_management_control_point": canonicalUUID(0x2AA4),
    "bond_management_feature": canonicalUUID(0x2AA5),
    "boot_keyboard_input_report": canonicalUUID(0x2A22),
    "boot_keyboard_output_report": canonicalUUID(0x2A32),
    "boot_mouse_input_report": canonicalUUID(0x2A33),
    "gap.central_address_resolution_support": canonicalUUID(0x2AA6),
    "cgm_feature": canonicalUUID(0x2AA8),
    "cgm_measurement": canonicalUUID(0x2AA7),
    "cgm_session_run_time": canonicalUUID(0x2AAB),
    "cgm_session_start_time": canonicalUUID(0x2AAA),
    "cgm_specific_ops_control_point": canonicalUUID(0x2AAC),
    "cgm_status": canonicalUUID(0x2AA9),
    "csc_feature": canonicalUUID(0x2A5C),
    "csc_measurement": canonicalUUID(0x2A5B),
    "current_time": canonicalUUID(0x2A2B),
    "cycling_power_control_point": canonicalUUID(0x2A66),
    "cycling_power_feature": canonicalUUID(0x2A65),
    "cycling_power_measurement": canonicalUUID(0x2A63),
    "cycling_power_vector": canonicalUUID(0x2A64),
    "database_change_increment": canonicalUUID(0x2A99),
    "date_of_birth": canonicalUUID(0x2A85),
    "date_of_threshold_assessment": canonicalUUID(0x2A86),
    "date_time": canonicalUUID(0x2A08),
    "day_date_time": canonicalUUID(0x2A0A),
    "day_of_week": canonicalUUID(0x2A09),
    "descriptor_value_changed": canonicalUUID(0x2A7D),
    "gap.device_name": canonicalUUID(0x2A00),
    "dew_point": canonicalUUID(0x2A7B),
    "digital": canonicalUUID(0x2A56),
    "dst_offset": canonicalUUID(0x2A0D),
    "elevation": canonicalUUID(0x2A6C),
    "email_address": canonicalUUID(0x2A87),
    "exact_time_256": canonicalUUID(0x2A0C),
    "fat_burn_heart_rate_lower_limit": canonicalUUID(0x2A88),
    "fat_burn_heart_rate_upper_limit": canonicalUUID(0x2A89),
    "firmware_revision_string": canonicalUUID(0x2A26),
    "first_name": canonicalUUID(0x2A8A),
    "five_zone_heart_rate_limits": canonicalUUID(0x2A8B),
    "floor_number": canonicalUUID(0x2AB2),
    "gender": canonicalUUID(0x2A8C),
    "glucose_feature": canonicalUUID(0x2A51),
    "glucose_measurement": canonicalUUID(0x2A18),
    "glucose_measurement_context": canonicalUUID(0x2A34),
    "gust_factor": canonicalUUID(0x2A74),
    "hardware_revision_string": canonicalUUID(0x2A27),
    "heart_rate_control_point": canonicalUUID(0x2A39),
    "heart_rate_max": canonicalUUID(0x2A8D),
    "heart_rate_measurement": canonicalUUID(0x2A37),
    "heat_index": canonicalUUID(0x2A7A),
    "height": canonicalUUID(0x2A8E),
    "hid_control_point": canonicalUUID(0x2A4C),
    "hid_information": canonicalUUID(0x2A4A),
    "hip_circumference": canonicalUUID(0x2A8F),
    "humidity": canonicalUUID(0x2A6F),
    "ieee_11073-20601_regulatory_certification_data_list": canonicalUUID(0x2A2A),
    "indoor_positioning_configuration": canonicalUUID(0x2AAD),
    "intermediate_blood_pressure": canonicalUUID(0x2A36),
    "intermediate_temperature": canonicalUUID(0x2A1E),
    "irradiance": canonicalUUID(0x2A77),
    "language": canonicalUUID(0x2AA2),
    "last_name": canonicalUUID(0x2A90),
    "latitude": canonicalUUID(0x2AAE),
    "ln_control_point": canonicalUUID(0x2A6B),
    "ln_feature": canonicalUUID(0x2A6A),
    "local_east_coordinate.xml": canonicalUUID(0x2AB1),
    "local_north_coordinate": canonicalUUID(0x2AB0),
    "local_time_information": canonicalUUID(0x2A0F),
    "location_and_speed": canonicalUUID(0x2A67),
    "location_name": canonicalUUID(0x2AB5),
    "longitude": canonicalUUID(0x2AAF),
    "magnetic_declination": canonicalUUID(0x2A2C),
    "magnetic_flux_density_2D": canonicalUUID(0x2AA0),
    "magnetic_flux_density_3D": canonicalUUID(0x2AA1),
    "manufacturer_name_string": canonicalUUID(0x2A29),
    "maximum_recommended_heart_rate": canonicalUUID(0x2A91),
    "measurement_interval": canonicalUUID(0x2A21),
    "model_number_string": canonicalUUID(0x2A24),
    "navigation": canonicalUUID(0x2A68),
    "new_alert": canonicalUUID(0x2A46),
    "gap.peripheral_preferred_connection_parameters": canonicalUUID(0x2A04),
    "gap.peripheral_privacy_flag": canonicalUUID(0x2A02),
    "plx_continuous_measurement": canonicalUUID(0x2A5F),
    "plx_features": canonicalUUID(0x2A60),
    "plx_spot_check_measurement": canonicalUUID(0x2A5E),
    "pnp_id": canonicalUUID(0x2A50),
    "pollen_concentration": canonicalUUID(0x2A75),
    "position_quality": canonicalUUID(0x2A69),
    "pressure": canonicalUUID(0x2A6D),
    "protocol_mode": canonicalUUID(0x2A4E),
    "rainfall": canonicalUUID(0x2A78),
    "gap.reconnection_address": canonicalUUID(0x2A03),
    "record_access_control_point": canonicalUUID(0x2A52),
    "reference_time_information": canonicalUUID(0x2A14),
    "report": canonicalUUID(0x2A4D),
    "report_map": canonicalUUID(0x2A4B),
    "resting_heart_rate": canonicalUUID(0x2A92),
    "ringer_control_point": canonicalUUID(0x2A40),
    "ringer_setting": canonicalUUID(0x2A41),
    "rsc_feature": canonicalUUID(0x2A54),
    "rsc_measurement": canonicalUUID(0x2A53),
    "sc_control_point": canonicalUUID(0x2A55),
    "scan_interval_window": canonicalUUID(0x2A4F),
    "scan_refresh": canonicalUUID(0x2A31),
    "sensor_location": canonicalUUID(0x2A5D),
    "serial_number_string": canonicalUUID(0x2A25),
    "gatt.service_changed": canonicalUUID(0x2A05),
    "software_revision_string": canonicalUUID(0x2A28),
    "sport_type_for_aerobic_and_anaerobic_thresholds": canonicalUUID(0x2A93),
    "supported_new_alert_category": canonicalUUID(0x2A47),
    "supported_unread_alert_category": canonicalUUID(0x2A48),
    "system_id": canonicalUUID(0x2A23),
    "temperature": canonicalUUID(0x2A6E),
    "temperature_measurement": canonicalUUID(0x2A1C),
    "temperature_type": canonicalUUID(0x2A1D),
    "three_zone_heart_rate_limits": canonicalUUID(0x2A94),
    "time_accuracy": canonicalUUID(0x2A12),
    "time_source": canonicalUUID(0x2A13),
    "time_update_control_point": canonicalUUID(0x2A16),
    "time_update_state": canonicalUUID(0x2A17),
    "time_with_dst": canonicalUUID(0x2A11),
    "time_zone": canonicalUUID(0x2A0E),
    "true_wind_direction": canonicalUUID(0x2A71),
    "true_wind_speed": canonicalUUID(0x2A70),
    "two_zone_heart_rate_limit": canonicalUUID(0x2A95),
    "tx_power_level": canonicalUUID(0x2A07),
    "uncertainty": canonicalUUID(0x2AB4),
    "unread_alert_status": canonicalUUID(0x2A45),
    "user_control_point": canonicalUUID(0x2A9F),
    "user_index": canonicalUUID(0x2A9A),
    "uv_index": canonicalUUID(0x2A76),
    "vo2_max": canonicalUUID(0x2A96),
    "waist_circumference": canonicalUUID(0x2A97),
    "weight": canonicalUUID(0x2A98),
    "weight_measurement": canonicalUUID(0x2A9D),
    "weight_scale_feature": canonicalUUID(0x2A9E),
    "wind_chill": canonicalUUID(0x2A79)
  };

  window.BluetoothUUID.descriptor = {
    "gatt.characteristic_extended_properties": canonicalUUID(0x2900),
    "gatt.characteristic_user_description": canonicalUUID(0x2901),
    "gatt.client_characteristic_configuration": canonicalUUID(0x2902),
    "gatt.server_characteristic_configuration": canonicalUUID(0x2903),
    "gatt.characteristic_presentation_format": canonicalUUID(0x2904),
    "gatt.characteristic_aggregate_format": canonicalUUID(0x2905),
    "valid_range": canonicalUUID(0x2906),
    "external_report_reference": canonicalUUID(0x2907),
    "report_reference": canonicalUUID(0x2908),
    "value_trigger_setting": canonicalUUID(0x290A),
    "es_configuration": canonicalUUID(0x290B),
    "es_measurement": canonicalUUID(0x290C),
    "es_trigger_setting": canonicalUUID(0x290D)
  };

  window.BluetoothUUID.getService = ResolveUUIDName('service');
  window.BluetoothUUID.getCharacteristic = ResolveUUIDName('characteristic');
  window.BluetoothUUID.getDescriptor = ResolveUUIDName('descriptor');


  /* TODO: Handle the Bluetooth tree and opt_capture.
   var bluetoothListeners = new Map();  // type -> Set<listener>
   navigator.bluetooth.addEventListener = function(type, listener, opt_capture) {
   var typeListeners = bluetoothListeners.get(type);
   if (!typeListeners) {
   typeListeners = new Set();
   bluetoothListeners.set(type, typeListeners);
   }
   typeListeners.add(listener);
   }
   navigator.bluetooth.removeEventListener = function(type, listener, opt_capture) {
   var typeListeners = bluetoothListeners.get(type);
   if (!typeListeners) {
   return;
   }
   typeListeners.remove(listener);
   }
   var dispatchSymbol = Symbol('dispatch');
   navigator.bluetooth.dispatchEvent = function(event, target) {
   if (event[dispatchSymbol]) {
   throw NamedError('InvalidStateError');
   }
   event[dispatchSymbol] = true;
   try {
   event.isTrusted = false;
   event.target = target;
   event.eventPhase = Event.AT_TARGET;
   var typeListeners = bluetoothListeners.get(event.type);
   var handled = false;
   if (typeListeners) {
   for (var listener of typeListeners) {
   handled = listener(event);
   if (handled) {
   break;
   }
   }
   }
   return handled;
   } finally {
   delete event[dispatchSymbol];
   }
   }
   */

  navigator.bluetooth.requestDevice = function (requestDeviceOptions) {
    if (!requestDeviceOptions.filters || requestDeviceOptions.filters.length === 0) {
      throw new TypeError('The first argument to navigator.bluetooth.requestDevice() must have a non-zero length filters parameter');
    }
    var validatedDeviceOptions = {}

    var filters = requestDeviceOptions.filters;
    filters = filters.map(function (filter) {
      return {
        services: filter.services.map(window.BluetoothUUID.getService),
        name: filter.name,
        namePrefix: filter.namePrefix
      };
    });
    validatedDeviceOptions.filters = filters;
    validatedDeviceOptions.name = filters;
    validatedDeviceOptions.filters = filters;


    var optionalServices = requestDeviceOptions.optionalService;
    if (optionalServices) {
      optionalServices = optionalServices.services.map(window.BluetoothUUID.getService)
      validatedDeviceOptions.optionalServices = optionalServices;
    }

    //first we send a request to start scanning
    sendMessage("bluetooth.requestDevice", [validatedDeviceOptions]).then(function () {
      console.log('started searching for BT device');
    }).catch(function (e) {
      console.log("Error starting to search for device", e);
    });

    //then we wait for native to send us a device (or deny the request)
    return new Promise(function (resolve, reject) {
      foundDevice = function (success, result) {
        console.log("Device in promise:", result);
        var device = new BluetoothDevice(result)
        if (success) {
          resolve(result)
        } else {
          reject(result)
        }
      }
    })
  }

  // Events:

  /*
   function BluetoothEvent(type, initDict) {
   this.type = type;
   initDict = initDict || {};
   this.bubbles = !!initDict.bubbles;
   this.cancelable = !!initDict.cancelable;
   };
   BluetoothEvent.prototype = {
   target: null,
   currentTarget: null,
   eventPhase: Event.NONE,
   };

   chrome.bluetoothLowEnergy.onCharacteristicValueChanged.addListener(function(chromeCharacteristic) {
   updateCharacteristic(chromeCharacteristic).then(function(characteristic) {
   var event = new BluetoothEvent('characteristicvaluechanged');
   event.characteristic = characteristic;
   event.value = characteristic.value;
   navigator.bluetooth.dispatchEvent(event, characteristic);
   });
   });

   */


  //Communication with Native
  var _messageCount = 0;
  var _callbacks = {}; // callbacks for responses to requests
  var foundDevice; // called when user has selected a device

  function sendMessage(method, args) {
    var callbackID, message;
    callbackID = _messageCount;

    message = {
      method: method,
      arguments: args,
      callbackID: callbackID
    };

    window.webkit.messageHandlers.bluetooth.postMessage(message);
    console.log("<--", message);
    _messageCount++;
    return new Promise(function (resolve, reject) {
      _callbacks[callbackID] = function (success, result) {
        if (success) {
          Promise.resolve(result);
        } else {
          Promise.reject(result);
        }
        return delete _callbacks[callbackID];
      };
    });
  }

  function recieveMessage(messageType, success, resultString, callbackID) {
    console.log("-->", messageType, success, resultString, callbackID);
    var result = JSON.parse(resultString);
    switch (messageType) {
      case "found-device":
        foundDevice(success, result);
        break;
      case "response":
        console.log('resposne AAAAA');
        _callbacks[callbackID](success, result);
        break;
      default:
        console.log("Unrecognised message from native:" + message);
    }
  }

})();