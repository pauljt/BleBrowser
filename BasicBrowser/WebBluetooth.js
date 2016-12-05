// adapted from chrome app polyfill https://github.com/WebBluetoothCG/chrome-app-polyfill

(function () {
  "use strict";

  if (navigator.bluetooth) {
    //already exists, don't polyfill
    console.log('navigator.bluetooth already exists, skipping polyfill')
    return;
  }

  function _arrayBufferToBase64(buffer) {
    var binary = '';
    var bytes = new Uint8Array(buffer);
    var len = bytes.byteLength;
    for (let ii = 0; ii < len; ii++) {
        binary += String.fromCharCode(bytes[ii]);
    }
    return window.btoa(binary);
}

  // https://webbluetoothcg.github.io/web-bluetooth/ interface
  function BluetoothDevice(deviceJSON) {
    console.log("got device: ", deviceJSON.id);
    this._id = deviceJSON.id;
    this._name = deviceJSON.name;

    this._adData = {};
    if (deviceJSON.adData) {
      this._adData.appearance = deviceJSON.adData.appearance || "";
      this._adData.txPower = deviceJSON.adData.txPower || 0;
      this._adData.rssi = deviceJSON.adData.rssi || 0;
      this._adData.manufacturerData = deviceJSON.adData.manufacturerData || [];
      this._adData.serviceData = deviceJSON.adData.serviceData || [];
    }

    this._deviceClass = deviceJSON.deviceClass || 0;
    this._vendorIdSource = deviceJSON.vendorIdSource || "bluetooth";
    this._vendorId = deviceJSON.vendorId || 0;
    this._productId = deviceJSON.productId || 0;
    this._productVersion = deviceJSON.productVersion || 0;
    this._gatt = new BluetoothRemoteGATTServer(this);
    this._uuids = deviceJSON.uuids;
  };

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
    get gatt() {
      return this._gatt;
    },
    get uuids() {
      return this._uuids;
    },
    toString: function () {
      return this._id;
    },
    addEventListener: function () {
      console.log("DUMMY device addEventListener");
    }
  };

  function BluetoothRemoteGATTServer(webBluetoothDevice) {
    this._device = webBluetoothDevice;
    this._connected = false;

    this._callRemote = function (method) {
      var self = this;
      var args = Array.prototype.slice.call(arguments).slice(1, arguments.length)
      return sendMessage("bluetooth:deviceMessage", {method: method, args: args, deviceId: self._device.id})
    }

  };
  BluetoothRemoteGATTServer.prototype = {
    get device() {
      return this._device;
    },
    get connected() {
      return this._connected;
    },
    connect: function () {
      var self = this;
      return self._callRemote("BluetoothRemoteGATTServer.connect")
        .then(function () {
          self._connected = true;
          return self;
        });
    },
    disconnect: function () {
      var self = this;
      return self._callRemote("BluetoothRemoteGATTServer.disconnect")
        .then(function () {
          self._connected = false;
        });
    },
    getPrimaryService: function (UUID) {
      var self = this;
      var canonicalUUID = window.BluetoothUUID.getService(UUID)
      return self._callRemote("BluetoothRemoteGATTServer.getPrimaryService", canonicalUUID)
        .then(function (service) {
          console.log("GOT SERVICE:"+service)
          return new BluetoothGATTService(self._device, canonicalUUID, true);
        })
    },

    getPrimaryServices: function (UUID) {
      var self = this;
      var canonicalUUID = window.BluetoothUUID.getService(UUID)
      return self._callRemote("BluetoothRemoteGATTServer.getPrimaryService", canonicalUUID)
        .then(function (servicesJSON) {
          var servicesData = JSON.parse(servicesJSON);
          var services = [];

          // this is a problem - all services will have the same information (UUID) so no way for this side of the code to differentiate.
          // we need to add an identifier GUID to tell them apart
          servicesData.forEach(function (service) {
            services.push(new BluetoothGATTService(self._device, canonicalUUID, characteristicUuid, true))
          });
          return services;
        });
    },
    toString: function () {
      return "BluetoothRemoteGATTServer";
    }
  };

  function BluetoothGATTService(device, uuid, isPrimary) {
    if (device == null || uuid == null || isPrimary == null) {
      throw Error("Invalid call to BluetoothGATTService constructor")
    }
    this._device = device
    this._uuid = uuid;
    this._isPrimary = isPrimary;

    this._callRemote = function (method) {
      var self = this;
      var args = Array.prototype.slice.call(arguments).slice(1, arguments.length)
      return sendMessage("bluetooth:deviceMessage", {
        method: method,
        args: args,
        deviceId: self._device.id,
        uuid: self._uuid
      })
    }
  }

  BluetoothGATTService.prototype = {
    get device() {
      return this._device;
    },
    get uuid() {
      return this._uuid;
    },
    get isPrimary() {
      return this._isPrimary
    },
    getCharacteristic: function (uuid) {
      var self = this;
      var canonicalUUID = BluetoothUUID.getCharacteristic(uuid)

      return self._callRemote("BluetoothGATTService.getCharacteristic",
        self.uuid, canonicalUUID)
        .then(function (CharacteristicJSON) {
          //todo check we got the correct char UUID back.
          console.log('Got characteristic: ' + uuid);
          return new BluetoothGATTCharacteristic(self, canonicalUUID, CharacteristicJSON.properties);
        });
    },
    getCharacteristics: function (uuid) {
      var self = this;
      var canonicalUUID = BluetoothUUID.getCharacteristic(uuid)

      return callRemote("BluetoothGATTService.getCharacteristic",
        self.uuid, canonicalUUID)
        .then(function (CharacteristicJSON) {
          //todo check we got the correct char UUID back.
          var characteristic = JSON.parse(CharacteristicJSON);
          return new BluetoothGATTCharacteristic(self, canonicalUUID, CharacteristicJSON.properties);
        });
    },
    getIncludedService: function (uuid) {
      throw new Error('Not implemented');
    },
    getIncludedServices: function (uuids) {
      throw new Error('Not implemented');
    }
  };

  function BluetoothGATTCharacteristic(service, uuid, properties) {
    this._service = service;
    this._uuid = uuid;
    this._properties = properties;
    this._value = null;

    this._callRemote = function (method) {
      var self = this;
      var args = Array.prototype.slice.call(arguments).slice(1, arguments.length);
      console.log('GATTChar _callRemote args', args);
      return sendMessage("bluetooth:deviceMessage", {
        method: method,
        args: args,
        deviceId: self._service.device.id,
        uuid: self._uuid
      })
    }
  }

  BluetoothGATTCharacteristic.prototype = {
    get service() {
      return this._service;
    },
    get uuid() {
      return this._uuid;
    },
    get properties() {
      return this._properties;
    },
    get value() {
      return this._value;
    },
    getDescriptor: function (descriptor) {
      var self = this;
      throw new Error('Not implemented');
    },
    getDescriptors: function (descriptor) {
      var self = this;
    },
    readValue: function () {
      var self = this;
      return self._callRemote("BluetoothGATTCharacteristic.readValue", self._service.uuid, self._uuid)
        .then(function (valueEncoded) {
          self._value = str2ab(atob(valueEncoded))
          console.log(valueEncoded,":",self._value)
          return new DataView(self._value,0);
        });
    },
    writeValue: function (value) {
      // Can't send raw array bytes since we use JSON, so base64 encode.
      let v64 = _arrayBufferToBase64(value)
      var self = this;
      return self._callRemote(
        "BluetoothGATTCharacteristic.writeValue", self._service.uuid,
        self._uuid, v64);
    },
    startNotifications: function () {
      var self = this;
      return self._callRemote("BluetoothGATTCharacteristic.startNotifications")
    },
    stopNotifications: function () {
      var self = this;
      return self._callRemote("BluetoothGATTCharacteristic.stopNotifications")
    },
    addEventListener: () => {
      console.log("DUMMY characteristic addEventListener")
    }
  };

  function BluetoothCharacteristicProperties() {

  }

  BluetoothCharacteristicProperties.prototype = {
    get broadcast() {
      return this._broadcast;
    },
    get read() {
      return this._read;
    },
    get writeWithoutResponse() {
      return this._writeWithoutResponse;
    },
    get write() {
      return this._write;
    },
    get notify() {
      return this._notify;
    },
    get indicate() {
      return this._indicate;
    },
    get authenticatedSignedWrites() {
      return this._authenticatedSignedWrites;
    },
    get reliableWrite() {
      return this._reliableWrite;
    },
    get writableAuxiliaries() {
      return this._writableAuxiliaries;
    }
  }

  function BluetoothGATTDescriptor(characteristic, uuid) {
    this._characteristic = characteristic;
    this._uuid = uuid;

    this._callRemote = function (method) {
      var self = this;
      var args = Array.prototype.slice.call(arguments).slice(1, arguments.length)
      console.log("Send device message with args", args);
      return sendMessage("bluetooth:deviceMessage", {
        method: method,
        args: args,
        deviceId: self._characteristic.service.device.id,
        uuid: self._uuid
      })
    }
  }

  BluetoothGATTDescriptor.prototype = {
    get characteristic() {
      return this._characteristic;
    },
    get uuid() {
      return this._uuid;
    },
    get writableAuxiliaries() {
      return this._value;
    },
    readValue: function () {
      return callRemote("BluetoothGATTDescriptor.startNotifications")
    },
    writeValue: function () {
      return callRemote("BluetoothGATTDescriptor.startNotifications")
    }
  };

  function canonicalUUID(uuidAlias) {
    uuidAlias >>>= 0;  // Make sure the number is positive and 32 bits.
    var strAlias = "0000000" + uuidAlias.toString(16);
    strAlias = strAlias.substr(-8);
    return strAlias + "-0000-1000-8000-00805f9b34fb"
  }

  var uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

  var BluetoothUUID = {};
  BluetoothUUID.canonicalUUID = canonicalUUID;
  BluetoothUUID.service = {
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

  BluetoothUUID.characteristic = {
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

  BluetoothUUID.descriptor = {
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

  function ResolveUUIDName(tableName) {
    var table = BluetoothUUID[tableName];
    return function (name) {
      if (typeof name === "number") {
        return canonicalUUID(name);
      } else if (uuidRegex.test(name.toLowerCase())) {
        //note native IOS bridges converts to uppercase since IOS seems to demand this.
        return name.toLowerCase();
      } else if (table.hasOwnProperty(name)) {
        return table[name];
      } else {
        throw new Error('SyntaxError: "' + name + '" is not a known ' + tableName + ' name.');
      }
    }
  }

  BluetoothUUID.getService = ResolveUUIDName('service');
  BluetoothUUID.getCharacteristic = ResolveUUIDName('characteristic');
  BluetoothUUID.getDescriptor = ResolveUUIDName('descriptor');


  var bluetooth = {};
  bluetooth.requestDevice = function (requestDeviceOptions) {
    if (!requestDeviceOptions.filters || requestDeviceOptions.filters.length === 0) {
      message = 'The first argument to navigator.bluetooth.requestDevice() must have a non-zero length filters parameter';
      console.log(message);
      throw new TypeError(message);
    }
    var validatedDeviceOptions = {}

    var filters = requestDeviceOptions.filters;
    filters = filters.map(function (filter) {
      if (!filter.services) filter.services = [];
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

    return sendMessage("bluetooth:requestDevice", validatedDeviceOptions)
      .then(function (deviceJSON) {
        var device = JSON.parse(deviceJSON);
        return new BluetoothDevice(device);
      });
  }


  ////////////Communication with Native
  var _messageCount = 0;
  var _callbacks = {}; // callbacks for responses to requests

  function sendMessage(type, data) {

    var callbackID, message;
    callbackID = _messageCount;

    if (typeof type == 'undefined') {
      throw "CallRemote should never be called without a type!"
    }

    message = {
      type: type,
      data: data,
      callbackID: callbackID
    };

    console.log("<-- " + type, JSON.stringify(data));
    window.webkit.messageHandlers.bluetooth.postMessage(message);

    _messageCount++;
    return new Promise(function (resolve, reject) {
      _callbacks[callbackID] = function (success, result) {
        if (success) {
          resolve(result);
        } else {
          reject(result);
        }
        return delete _callbacks[callbackID];
      };
    });
  }

  function receiveMessage(messageType, success, resultString, callbackID) {
    console.log("-->", messageType, success, resultString, callbackID);

    switch (messageType) {
      case "response":
        console.log("result:", resultString);
        _callbacks[callbackID](success, resultString);
        break;
      default:
        console.log("Unrecognised message from native:" + message);
    }
  }

  function NamedError(name, message) {
    var e = new Error(message || '');
    e.name = name;
    return e;
  };

  //Safari 9 doesn't have TextDecoder API
  function ab2str(buf) {
    return String.fromCharCode.apply(null, new Uint16Array(buf));
  }

  function str2ab(str) {
    var buf = new ArrayBuffer(str.length * 2); // 2 bytes for each char
    var bufView = new Uint16Array(buf);
    for (var i = 0, strLen = str.length; i < strLen; i++) {
      bufView[i] = str.charCodeAt(i);
    }
    return buf;
  }


  //Exposed interfaces
  window.BluetoothDevice = BluetoothDevice;
  window.BluetoothUUID = BluetoothUUID;
  window.receiveMessage = receiveMessage;
  navigator.bluetooth = bluetooth;
  window.BluetoothUUID = BluetoothUUID;

})();
