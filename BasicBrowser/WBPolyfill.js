/*jslint
        browser
*/
/*global
        atob, Event, window
*/
// adapted from chrome app polyfill https://github.com/WebBluetoothCG/chrome-app-polyfill

(function () {
    "use strict";

    function nslog(message) {
        window.webkit.messageHandlers.logger.postMessage(message);
    }
    nslog("Initialize web bluetooth runtime");

    if (navigator.bluetooth) {
        // already exists, don't polyfill
        console.log('navigator.bluetooth already exists, skipping polyfill');
        return;
    }

    let native;

    function _arrayBufferToBase64(buffer) {
        let binary = '';
        let bytes = new Uint8Array(buffer);
        bytes.forEach(function (byte) {
            binary += String.fromCharCode(byte);
        });
        return window.btoa(binary);
    }

    //Safari 9 doesn't have TextDecoder API
    function str2ab(str) {
        let buf = new ArrayBuffer(str.length * 2); // 2 bytes for each char
        let bufView = new Uint16Array(buf);
        let ii;
        let strLen = str.length;
        for (ii = 0; ii < strLen; ii += 1) {
            bufView[ii] = str.charCodeAt(ii);
        }
        return buf;
    }

    //
    // We need an EventTarget implementation. This one nicked wholesale from
    // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget
    //
    nslog("Build EventTarget");
    function EventTarget() {
        this.listeners = {};
    }

    EventTarget.prototype.addEventListener = function (type, callback) {
        if (this.listeners[type] === undefined) {
            this.listeners[type] = [];
        }
        this.listeners[type].push(callback);
    };
    EventTarget.prototype.removeEventListener = function (type, callback) {

        let stack = this.listeners[type];
        if (stack === undefined) {
            return;
        }
        let l = stack.length;
        let ii;
        for (ii = 0; ii < l; ii += 1) {
            if (stack[ii] === callback) {
                stack.splice(ii, 1);
                return this.removeEventListener(type, callback);
            }
        }
    };
    EventTarget.prototype.dispatchEvent = function (event) {
        let stack = this.listeners[event.type];
        if (stack === undefined) {
            return;
        }
        event.currentTarget = this;
        stack.forEach(function (cb) {
            try {
                cb.call(this, event);
            } catch (e) {
                console.log("Exception dispatching to callback " + cb, e);
            }
        });
    };

    //
    // And this function is how we add EventTarget to the "sub"classes.
    //
    function mixin(target, src) {
        Object.assign(target.prototype, src.prototype);
        target.prototype.constructor = target;
    }

    function defineROProperties(target, roDescriptors) {
        Object.keys(roDescriptors).forEach(function (key) {
            Object.defineProperty(target, key, {value: roDescriptors[key]});
        });
    }

    // https://webbluetoothcg.github.io/web-bluetooth/ interface
    nslog("Create BluetoothDevice");
    function BluetoothDevice(deviceJSON) {
        EventTarget.call(this);

        let roProps = {
            adData: {},
            deviceClass: deviceJSON.deviceClass || 0,
            id: deviceJSON.id,
            gatt: new native.BluetoothRemoteGATTServer(this),
            productId: deviceJSON.productId || 0,
            productVersion: deviceJSON.productVersion || 0,
            uuids: deviceJSON.uuids,
            vendorId: deviceJSON.vendorId || 0,
            vendorIdSource: deviceJSON.vendorIdSource || "bluetooth"
        };
        defineROProperties(this, roProps);

        this.name = deviceJSON.name;

        if (deviceJSON.adData) {
            this.adData.appearance = deviceJSON.adData.appearance || "";
            this.adData.txPower = deviceJSON.adData.txPower || 0;
            this.adData.rssi = deviceJSON.adData.rssi || 0;
            this.adData.manufacturerData = deviceJSON.adData.manufacturerData || [];
            this.adData.serviceData = deviceJSON.adData.serviceData || [];
        }
    }

    BluetoothDevice.prototype = {
        toString: function () {
            return "BluetoothDevice(" + this.id.slice(0, 10) + ")";
        },
        handleSpontaneousDisconnectEvent: function () {
            // Code references as per
            // https://webbluetoothcg.github.io/web-bluetooth/#disconnection-events
            // 1. not implemented
            // 2.
            if (!this.gatt.connected) {
                return;
            }
            // 3.1
            this.gatt.connected = false;
            // 3.2-3.7 not implemented
            // 3.8
            this.dispatchEvent(new native.BluetoothEvent("gattserverdisconnected", this));
        }
    };
    mixin(BluetoothDevice, EventTarget);

    nslog("Create BluetoothRemoteGATTServer");
    function BluetoothRemoteGATTServer(webBluetoothDevice) {
        if (webBluetoothDevice === undefined) {
            throw new Error("Attempt to create BluetoothRemoteGATTServer with no device");
        }
        defineROProperties(this, {device: webBluetoothDevice});
        this.connected = false;
        this.connectionTransactionIDs = [];
    }
    BluetoothRemoteGATTServer.prototype = {
        connect: function () {
            let self = this;
            let tid = native.getTransactionID();
            this.connectionTransactionIDs.push(tid);
            return this.sendMessage("connectGATT", {callbackID: tid})
                .then(function () {
                    self.connected = true;
                    native.registerDeviceForNotifications(self.device);
                    return self;
                });
        },
        disconnect: function () {
            this.connectionTransactionIDs.forEach((tid) => native.cancelTransaction(tid));
            this.connectionTransactionIDs = [];
            let self = this;
            return this.sendMessage("disconnectGATT")
                .then(function () {
                    native.unregisterDeviceForNotifications(self.device);
                    self.connected = false;
                });
        },
        getPrimaryService: function (UUID) {
            let canonicalUUID = window.BluetoothUUID.getService(UUID);
            let self = this;
            return this.sendMessage("getPrimaryService", {data: {serviceUUID: canonicalUUID}})
                .then(() => new native.BluetoothRemoteGATTService(
                    self.device,
                    canonicalUUID,
                    true
                ));
        },

        getPrimaryServices: function (UUID) {
            if (true) {
                throw new Error("Not implemented");
            }
            let device = this.device;
            let canonicalUUID = window.BluetoothUUID.getService(UUID);
            return this.sendMessage("getPrimaryServices", {data: {serviceUUID: canonicalUUID}})
                .then(function (servicesJSON) {
                    let servicesData = JSON.parse(servicesJSON);
                    let services = servicesData;
                    services = device;
                    services = [];

                    // this is a problem - all services will have the same information (UUID) so no way for this side of the code to differentiate.
                    // we need to add an identifier GUID to tell them apart
                    // servicesData.forEach(
                    //     (service) => services.push(
                    //         new native.BluetoothRemoteGATTService(device, canonicalUUID, true)
                    //     )
                    // );
                    return services;
                });
        },
        sendMessage: function (type, messageParms) {
            messageParms = messageParms || {};
            messageParms.data = messageParms.data || {};
            messageParms.data.deviceId = this.device.id;
            return native.sendMessage("device:" + type, messageParms);
        },
        toString: function () {
            return "BluetoothRemoteGATTServer(" + this.device.toString() + ")";
        }
    };

    nslog("Create BluetoothRemoteGATTService");
    function BluetoothRemoteGATTService(device, uuid, isPrimary) {
        if (device === undefined || uuid === undefined || isPrimary === undefined) {
            throw new Error("Invalid call to BluetoothRemoteGATTService constructor");
        }
        defineROProperties(this, {
            device: device,
            uuid: uuid,
            isPrimary: isPrimary
        });
    }

    BluetoothRemoteGATTService.prototype = {
        getCharacteristic: function (uuid) {
            let canonicalUUID = native.BluetoothUUID.getCharacteristic(uuid);
            let service = this;
            return this.sendMessage(
                "getCharacteristic",
                {data: {characteristicUUID: canonicalUUID}}
            ).then(function (CharacteristicJSON) {
                console.log('Got characteristic', uuid);
                return new native.BluetoothRemoteGATTCharacteristic(
                    service,
                    canonicalUUID,
                    CharacteristicJSON.properties
                );
            });
        },
        getCharacteristics: function (ignore) {
            throw new Error('Not implemented');
        },
        getIncludedService: function (ignore) {
            throw new Error('Not implemented');
        },
        getIncludedServices: function (ignore) {
            throw new Error('Not implemented');
        },
        sendMessage: function (type, messageParms) {
            messageParms = messageParms || {};
            messageParms.data = messageParms.data || {};
            messageParms.data.serviceUUID = this.uuid;
            return this.device.gatt.sendMessage(type, messageParms);
        },
        toString: function () {
            return ("BluetoothRemoteGATTService(" + this.uuid + ")");
        }
    };

    nslog("Create BluetoothRemoteGATTCharacteristic");
    function BluetoothRemoteGATTCharacteristic(service, uuid, properties) {
        let roProps = {
            service: service,
            properties: properties,
            uuid: uuid
        };
        defineROProperties(this, roProps);
        this.value = null;
        EventTarget.call(this);
        native.registerCharacteristicForNotifications(this);
    }

    BluetoothRemoteGATTCharacteristic.prototype = {
        getDescriptor: function (ignore) {
            throw new Error('Not implemented');
        },
        getDescriptors: function (ignore) {
            throw new Error("Not implemented");
        },
        readValue: function () {
            let char = this;
            return this.sendMessage("readCharacteristicValue")
                .then(function (valueEncoded) {
                    char.value = new DataView(str2ab(atob(valueEncoded)));
                    return char.value;
                });
        },
        writeValue: function (value) {
            // Can't send raw array bytes since we use JSON, so base64 encode.
            let v64 = _arrayBufferToBase64(value);
            return this.sendMessage("writeCharacteristicValue", {data: {value: v64}});
        },
        startNotifications: function () {
            return this.sendMessage("startNotifications");
        },
        stopNotifications: function () {
            return this.sendMessage("stopNotifications");
        },
        sendMessage: function (type, messageParms) {
            messageParms = messageParms || {};
            messageParms.data = messageParms.data || {};
            messageParms.data.characteristicUUID = this.uuid;
            return this.service.sendMessage(type, messageParms);
        },
        toString: function () {
            return (
                "BluetoothRemoteGATTCharacteristic(" + this.service.toString() + ", " +
                this.uuid + ")"
            );
        }
    };
    mixin(BluetoothRemoteGATTCharacteristic, EventTarget);

    nslog("Create BluetoothGATTDescriptor");
    function BluetoothGATTDescriptor(characteristic, uuid) {
        defineROProperties(this, {characteristic: characteristic, uuid: uuid});
    }

    BluetoothGATTDescriptor.prototype = {
        get writableAuxiliaries() {
            return this.value;
        },
        readValue: function () {
            throw new Error("Not implemented");
        },
        writeValue: function () {
            throw new Error("Not implemented");
        }
    };

    function canonicalUUID(uuidAlias) {
        uuidAlias >>>= 0;  // Make sure the number is positive and 32 bits.
        let strAlias = "0000000" + uuidAlias.toString(16);
        strAlias = strAlias.substr(-8);
        return strAlias + "-0000-1000-8000-00805f9b34fb";
    }

    let uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

    nslog("Create BluetoothUUID");
    let BluetoothUUID = {};
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
    };

    BluetoothUUID.characteristic = {
        aerobic_heart_rate_lower_limit: canonicalUUID(0x2A7E),
        aerobic_heart_rate_upper_limit: canonicalUUID(0x2A84),
        aerobic_threshold: canonicalUUID(0x2A7F),
        age: canonicalUUID(0x2A80),
        aggregate: canonicalUUID(0x2A5A),
        alert_category_id: canonicalUUID(0x2A43),
        alert_category_id_bit_mask: canonicalUUID(0x2A42),
        alert_level: canonicalUUID(0x2A06),
        alert_notification_control_point: canonicalUUID(0x2A44),
        alert_status: canonicalUUID(0x2A3F),
        altitude: canonicalUUID(0x2AB3),
        anaerobic_heart_rate_lower_limit: canonicalUUID(0x2A81),
        anaerobic_heart_rate_upper_limit: canonicalUUID(0x2A82),
        anaerobic_threshold: canonicalUUID(0x2A83),
        analog: canonicalUUID(0x2A58),
        apparent_wind_direction: canonicalUUID(0x2A73),
        apparent_wind_speed: canonicalUUID(0x2A72),
        "gap.appearance": canonicalUUID(0x2A01),
        barometric_pressure_trend: canonicalUUID(0x2AA3),
        battery_level: canonicalUUID(0x2A19),
        blood_pressure_feature: canonicalUUID(0x2A49),
        blood_pressure_measurement: canonicalUUID(0x2A35),
        body_composition_feature: canonicalUUID(0x2A9B),
        body_composition_measurement: canonicalUUID(0x2A9C),
        body_sensor_location: canonicalUUID(0x2A38),
        bond_management_control_point: canonicalUUID(0x2AA4),
        bond_management_feature: canonicalUUID(0x2AA5),
        boot_keyboard_input_report: canonicalUUID(0x2A22),
        boot_keyboard_output_report: canonicalUUID(0x2A32),
        boot_mouse_input_report: canonicalUUID(0x2A33),
        "gap.central_address_resolution_support": canonicalUUID(0x2AA6),
        cgm_feature: canonicalUUID(0x2AA8),
        cgm_measurement: canonicalUUID(0x2AA7),
        cgm_session_run_time: canonicalUUID(0x2AAB),
        cgm_session_start_time: canonicalUUID(0x2AAA),
        cgm_specific_ops_control_point: canonicalUUID(0x2AAC),
        cgm_status: canonicalUUID(0x2AA9),
        csc_feature: canonicalUUID(0x2A5C),
        csc_measurement: canonicalUUID(0x2A5B),
        current_time: canonicalUUID(0x2A2B),
        cycling_power_control_point: canonicalUUID(0x2A66),
        cycling_power_feature: canonicalUUID(0x2A65),
        cycling_power_measurement: canonicalUUID(0x2A63),
        cycling_power_vector: canonicalUUID(0x2A64),
        database_change_increment: canonicalUUID(0x2A99),
        date_of_birth: canonicalUUID(0x2A85),
        date_of_threshold_assessment: canonicalUUID(0x2A86),
        date_time: canonicalUUID(0x2A08),
        day_date_time: canonicalUUID(0x2A0A),
        day_of_week: canonicalUUID(0x2A09),
        descriptor_value_changed: canonicalUUID(0x2A7D),
        "gap.device_name": canonicalUUID(0x2A00),
        dew_point: canonicalUUID(0x2A7B),
        digital: canonicalUUID(0x2A56),
        dst_offset: canonicalUUID(0x2A0D),
        elevation: canonicalUUID(0x2A6C),
        email_address: canonicalUUID(0x2A87),
        exact_time_256: canonicalUUID(0x2A0C),
        fat_burn_heart_rate_lower_limit: canonicalUUID(0x2A88),
        fat_burn_heart_rate_upper_limit: canonicalUUID(0x2A89),
        firmware_revision_string: canonicalUUID(0x2A26),
        first_name: canonicalUUID(0x2A8A),
        five_zone_heart_rate_limits: canonicalUUID(0x2A8B),
        floor_number: canonicalUUID(0x2AB2),
        gender: canonicalUUID(0x2A8C),
        glucose_feature: canonicalUUID(0x2A51),
        glucose_measurement: canonicalUUID(0x2A18),
        glucose_measurement_context: canonicalUUID(0x2A34),
        gust_factor: canonicalUUID(0x2A74),
        hardware_revision_string: canonicalUUID(0x2A27),
        heart_rate_control_point: canonicalUUID(0x2A39),
        heart_rate_max: canonicalUUID(0x2A8D),
        heart_rate_measurement: canonicalUUID(0x2A37),
        heat_index: canonicalUUID(0x2A7A),
        height: canonicalUUID(0x2A8E),
        hid_control_point: canonicalUUID(0x2A4C),
        hid_information: canonicalUUID(0x2A4A),
        hip_circumference: canonicalUUID(0x2A8F),
        humidity: canonicalUUID(0x2A6F),
        "ieee_11073-20601_regulatory_certification_data_list": canonicalUUID(0x2A2A),
        indoor_positioning_configuration: canonicalUUID(0x2AAD),
        intermediate_blood_pressure: canonicalUUID(0x2A36),
        intermediate_temperature: canonicalUUID(0x2A1E),
        irradiance: canonicalUUID(0x2A77),
        language: canonicalUUID(0x2AA2),
        last_name: canonicalUUID(0x2A90),
        latitude: canonicalUUID(0x2AAE),
        ln_control_point: canonicalUUID(0x2A6B),
        ln_feature: canonicalUUID(0x2A6A),
        "local_east_coordinate.xml": canonicalUUID(0x2AB1),
        local_north_coordinate: canonicalUUID(0x2AB0),
        local_time_information: canonicalUUID(0x2A0F),
        location_and_speed: canonicalUUID(0x2A67),
        location_name: canonicalUUID(0x2AB5),
        longitude: canonicalUUID(0x2AAF),
        magnetic_declination: canonicalUUID(0x2A2C),
        magnetic_flux_density_2D: canonicalUUID(0x2AA0),
        magnetic_flux_density_3D: canonicalUUID(0x2AA1),
        manufacturer_name_string: canonicalUUID(0x2A29),
        maximum_recommended_heart_rate: canonicalUUID(0x2A91),
        measurement_interval: canonicalUUID(0x2A21),
        model_number_string: canonicalUUID(0x2A24),
        navigation: canonicalUUID(0x2A68),
        new_alert: canonicalUUID(0x2A46),
        "gap.peripheral_preferred_connection_parameters": canonicalUUID(0x2A04),
        "gap.peripheral_privacy_flag": canonicalUUID(0x2A02),
        plx_continuous_measurement: canonicalUUID(0x2A5F),
        plx_features: canonicalUUID(0x2A60),
        plx_spot_check_measurement: canonicalUUID(0x2A5E),
        pnp_id: canonicalUUID(0x2A50),
        pollen_concentration: canonicalUUID(0x2A75),
        position_quality: canonicalUUID(0x2A69),
        pressure: canonicalUUID(0x2A6D),
        protocol_mode: canonicalUUID(0x2A4E),
        rainfall: canonicalUUID(0x2A78),
        "gap.reconnection_address": canonicalUUID(0x2A03),
        record_access_control_point: canonicalUUID(0x2A52),
        reference_time_information: canonicalUUID(0x2A14),
        report: canonicalUUID(0x2A4D),
        report_map: canonicalUUID(0x2A4B),
        resting_heart_rate: canonicalUUID(0x2A92),
        ringer_control_point: canonicalUUID(0x2A40),
        ringer_setting: canonicalUUID(0x2A41),
        rsc_feature: canonicalUUID(0x2A54),
        rsc_measurement: canonicalUUID(0x2A53),
        sc_control_point: canonicalUUID(0x2A55),
        scan_interval_window: canonicalUUID(0x2A4F),
        scan_refresh: canonicalUUID(0x2A31),
        sensor_location: canonicalUUID(0x2A5D),
        serial_number_string: canonicalUUID(0x2A25),
        "gatt.service_changed": canonicalUUID(0x2A05),
        software_revision_string: canonicalUUID(0x2A28),
        sport_type_for_aerobic_and_anaerobic_thresholds: canonicalUUID(0x2A93),
        supported_new_alert_category: canonicalUUID(0x2A47),
        supported_unread_alert_category: canonicalUUID(0x2A48),
        system_id: canonicalUUID(0x2A23),
        temperature: canonicalUUID(0x2A6E),
        temperature_measurement: canonicalUUID(0x2A1C),
        temperature_type: canonicalUUID(0x2A1D),
        three_zone_heart_rate_limits: canonicalUUID(0x2A94),
        time_accuracy: canonicalUUID(0x2A12),
        time_source: canonicalUUID(0x2A13),
        time_update_control_point: canonicalUUID(0x2A16),
        time_update_state: canonicalUUID(0x2A17),
        time_with_dst: canonicalUUID(0x2A11),
        time_zone: canonicalUUID(0x2A0E),
        true_wind_direction: canonicalUUID(0x2A71),
        true_wind_speed: canonicalUUID(0x2A70),
        two_zone_heart_rate_limit: canonicalUUID(0x2A95),
        tx_power_level: canonicalUUID(0x2A07),
        uncertainty: canonicalUUID(0x2AB4),
        unread_alert_status: canonicalUUID(0x2A45),
        user_control_point: canonicalUUID(0x2A9F),
        user_index: canonicalUUID(0x2A9A),
        uv_index: canonicalUUID(0x2A76),
        vo2_max: canonicalUUID(0x2A96),
        waist_circumference: canonicalUUID(0x2A97),
        weight: canonicalUUID(0x2A98),
        weight_measurement: canonicalUUID(0x2A9D),
        weight_scale_feature: canonicalUUID(0x2A9E),
        wind_chill: canonicalUUID(0x2A79)
    };

    BluetoothUUID.descriptor = {
        "gatt.characteristic_extended_properties": canonicalUUID(0x2900),
        "gatt.characteristic_user_description": canonicalUUID(0x2901),
        "gatt.client_characteristic_configuration": canonicalUUID(0x2902),
        "gatt.server_characteristic_configuration": canonicalUUID(0x2903),
        "gatt.characteristic_presentation_format": canonicalUUID(0x2904),
        "gatt.characteristic_aggregate_format": canonicalUUID(0x2905),
        valid_range: canonicalUUID(0x2906),
        external_report_reference: canonicalUUID(0x2907),
        report_reference: canonicalUUID(0x2908),
        value_trigger_setting: canonicalUUID(0x290A),
        es_configuration: canonicalUUID(0x290B),
        es_measurement: canonicalUUID(0x290C),
        es_trigger_setting: canonicalUUID(0x290D)
    };

    function resolveUUIDName(tableName) {
        let table = BluetoothUUID[tableName];
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
        };
    }

    BluetoothUUID.getService = resolveUUIDName('service');
    BluetoothUUID.getCharacteristic = resolveUUIDName('characteristic');
    BluetoothUUID.getDescriptor = resolveUUIDName('descriptor');

    nslog("Create bluetooth");
    let bluetooth = {};
    bluetooth.requestDevice = function (requestDeviceOptions) {
        if (!requestDeviceOptions) {
            throw new TypeError("requestDeviceOptions not provided");
        }
        let acceptAllDevices = requestDeviceOptions.acceptAllDevices;
        let filters = requestDeviceOptions.filters;
        if (acceptAllDevices) {
            if (filters && filters.length > 0) {
                throw new TypeError("acceptAllDevices was true but filters was not empty");
            }
            return native.sendMessage("requestDevice", {data: {filters: []}})
                .then(function (device) {
                    return new BluetoothDevice(device);
                });
        }

        let hasAtLeastOneFilter = false;
        filters = Array.prototype.map.call(filters, function (filter) {
            if (!filter.services) {
                filter.services = [];
            }
            if (filter.services.length > 0 ||
                    (filter.namePrefix !== undefined && filter.namePrefix.length > 0)) {
                hasAtLeastOneFilter = true;
            }
            return {
                services: filter.services.map(window.BluetoothUUID.getService),
                namePrefix: filter.namePrefix
            };
        });
        if (!hasAtLeastOneFilter) {
            throw new TypeError("Must specify at least one thing to filter on");
        }
        let validatedDeviceOptions = {};
        validatedDeviceOptions.filters = filters;

        // Optional services not yet suppoprted.
        // let optionalServices = requestDeviceOptions.optionalServices;
        // if (optionalServices) {
        //     optionalServices = optionalServices.services.map(window.BluetoothUUID.getService);
        //     validatedDeviceOptions.optionalServices = optionalServices;
        // }

        return native.sendMessage("requestDevice", {data: validatedDeviceOptions})
            .then(function (device) {
                return new BluetoothDevice(device);
            });
    };

    function BluetoothEvent(type, target) {
        defineROProperties(this, {type: type, target: target});
    }
    BluetoothEvent.prototype = {
        prototype: Event.prototype,
        constructor: BluetoothEvent
    };

    //
    // ===== Communication with Native =====
    //
    native = {
        messageCount: 0,
        callbacks: {}, // callbacks for responses to requests

        cancelTransaction: function (tid) {
            let trans = this.callbacks[tid];
            if (!trans) {
                console.log("No transaction " + tid + " outstanding to fail.");
                return;
            }
            delete this.callbacks[tid];
            trans(false, "Premature cancellation.");
        },
        getTransactionID: function () {
            let mc = this.messageCount;
            do {
                mc += 1;
            } while (native.callbacks[mc] !== undefined);
            this.messageCount = mc;
            return this.messageCount;
        },
        sendMessage: function (type, sendMessageParms) {

            let message;
            if (type === undefined) {
                throw new Error("CallRemote should never be called without a type!");
            }

            sendMessageParms = sendMessageParms || {};
            let data = sendMessageParms.data || {};
            let callbackID = sendMessageParms.callbackID || this.getTransactionID();
            message = {
                type: type,
                data: data,
                callbackID: callbackID
            };

            console.log("--> sending " + type, JSON.stringify(data));
            window.webkit.messageHandlers.bluetooth.postMessage(message);

            this.messageCount += 1;
            return new Promise(function (resolve, reject) {
                native.callbacks[callbackID] = function (success, result) {
                    if (success) {
                        resolve(result);
                    } else {
                        reject(result);
                    }
                    delete native.callbacks[callbackID];
                };
            });
        },
        receiveMessageResponse: function (success, resultString, callbackID) {
            console.log("<-- receiving response", success, resultString, callbackID);

            if (callbackID !== undefined && native.callbacks[callbackID]) {
                native.callbacks[callbackID](success, resultString);
            } else {
                console.log("Response for unknown callbackID", callbackID);
            }
        },
        devicesBeingNotified: {},
        registerDeviceForNotifications: function (device) {
            let did = device.id;
            if (native.devicesBeingNotified[did] === undefined) {
                native.devicesBeingNotified[did] = [];
            }
            let devs = native.devicesBeingNotified[did];
            devs.forEach(function (dev) {
                if (dev === device) {
                    throw new Error("Device already registered for notifications");
                }
            });
            console.log("Register device " + did + " for notifications");
            devs.push(device);
        },
        unregisterDeviceForNotifications: function (device) {
            let did = device.id;
            if (native.devicesBeingNotified[did] === undefined) {
                return;
            }
            let devs = native.devicesBeingNotified[did];
            let ii;
            for (ii = 0; ii < devs.length; ii += 1) {
                if (devs[ii] === device) {
                    devs.splice(ii, 1);
                    return;
                }
            }
        },
        receiveDeviceDisconnectEvent: function (deviceId) {
            console.log("<-- device disconnect event", deviceId);
            let devices = native.devicesBeingNotified[deviceId];
            if (devices === undefined || devices.length === 0) {
                console.log("Device not registered for notifications");
                return;
            }
            devices.forEach(function (device) {
                device.handleSpontaneousDisconnectEvent();
            });
        },
        characteristicsBeingNotified: {},
        registerCharacteristicForNotifications: function (characteristic) {
            let cid = characteristic.uuid;
            console.log("Registering char UUID", cid);
            if (native.characteristicsBeingNotified[cid] === undefined) {
                native.devicesBeingNotified[cid] = [];
            }
            native.devicesBeingNotified[cid].push(characteristic);
        },
        receiveCharacteristicValueNotification: function (characteristicId, d64) {
            let chars = native.devicesBeingNotified[characteristicId];
            console.log("<-- char val notification", characteristicId, d64);
            if (!chars) {
                console.log(
                    "Characteristic notification ignored for unknown characteristic",
                    characteristicId
                );
                console.log('Know characteristics', Object.keys(native.devicesBeingNotified));
                return;
            }
            let strData = atob(d64);
            let dataView = new DataView(str2ab(strData));
            chars.forEach(function (char) {
                char.value = dataView;
                char.dispatchEvent(new BluetoothEvent("characteristicvaluechanged", char));
            });
        },
        // defeat the linter's "out of scope" warnings for not yet defined functions
        BluetoothRemoteGATTCharacteristic: BluetoothRemoteGATTCharacteristic,
        BluetoothUUID: BluetoothUUID,
        BluetoothRemoteGATTServer: BluetoothRemoteGATTServer,
        BluetoothRemoteGATTService: BluetoothRemoteGATTService,
        BluetoothEvent: BluetoothEvent
    };

    //Exposed interfaces
    nslog("POLYFILL");
    window.BluetoothDevice = BluetoothDevice;
    window.BluetoothUUID = BluetoothUUID;
    window.receiveDeviceDisconnectEvent = native.receiveDeviceDisconnectEvent;
    window.receiveMessageResponse = native.receiveMessageResponse;
    window.receiveCharacteristicValueNotification = native.receiveCharacteristicValueNotification;
    navigator.bluetooth = bluetooth;
    window.BluetoothUUID = BluetoothUUID;
    nslog("navigator.bluetooth: " + navigator.bluetooth);
}());
