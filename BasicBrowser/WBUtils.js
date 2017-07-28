/*jslint
        browser
*/
/*global
        atob, BluetoothUUID, Event, uk, window
*/
eval('var uk = uk || {};');
if (!uk.co) {
    uk.co = {};
}
if (!uk.co.greenparksoftware) {
    uk.co.greenparksoftware = {};
}
uk.co.greenparksoftware.wbutils = {
    canonicaliseFilter: function (filter) {
        "use strict";
        // implemented as far as possible as per
        // https://webbluetoothcg.github.io/web-bluetooth/#bluetoothlescanfilterinit-canonicalizing
        let services = filter.services;
        let name = filter.name;
        let namePrefix = filter.namePrefix;

        let canonicalizedFilter = {};

        if (services === undefined && name === undefined && namePrefix === undefined) {
            throw new TypeError("Filter has no usable properties");
        }
        if (services !== undefined) {
            if (!services) {
                throw new TypeError('Filter has empty services');
            }
            let cservs = services.map(BluetoothUUID.getService);
            canonicalizedFilter.services = cservs;
        }

        return canonicalizedFilter;

    }
};
