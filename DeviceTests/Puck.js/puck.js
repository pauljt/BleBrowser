/*
--------------------------------------------------------------------
Puck.js BLE Interface library
                      Copyright 2016 Gordon Williams (gw@pur3.co.uk)
--------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
--------------------------------------------------------------------
This creates a 'Puck' object that can be used from the Web Browser.

Simple usage:

  Puck.write("LED1.set()\n")

Execute expression and return the result:

  Puck.eval("BTN.read()", function(d) {
    alert(d);
  });

Or write and wait for a result - this will return all characters,
including echo and linefeed from the REPL so you may want to send
`echo(0)` and use `console.log` when doing this.

  Puck.write("1+2\n", function(d) {
    alert(d);
  });

Or more advanced usage with control of the connection
 - allows multiple connections

  Puck.connect(function(connection) {
    if (!connection) throw "Error!";
    connection.on('data', function(d) { ... });
    connection.on('close', function() { ... });
    connection.write("1+2\n", function() {
      connection.close();
    });
  });

*/
var NORDIC_SERVICE = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
var NORDIC_TX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
var NORDIC_RX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

var Puck = (function() {
  if (typeof navigator == "undefined") return; // not running in a web browser

  var CHUNKSIZE = 16;

  function log(s) {
    if (puck.log) puck.log(s);
  }

  function ab2str(buf) {
    return String.fromCharCode.apply(null, new Uint8Array(buf));
  }

  function str2ab(str) {
    var buf = new ArrayBuffer(str.length);
    var bufView = new Uint8Array(buf);
    for (var i=0, strLen=str.length; i<strLen; i++) {
      bufView[i] = str.charCodeAt(i);
    }
    return buf;
  }


  function connect(callback) {
    if (!navigator.bluetooth) {
      window.alert("Web Bluetooth isn't enabled in your browser!");
      return;
    }

    var connection = {
      device: null,
      on : function(evt,cb) { this["on"+evt]=cb; },
      emit : function(evt,data) { if (this["on"+evt]) this["on"+evt](data); },
      isOpen : false,
      isOpening : true,
      txInProgress : false
    };
    var btServer = undefined;
    var btService;
    var connectionDisconnectCallback;
    var txCharacteristic;
    var rxCharacteristic;
    var txDataQueue = [];

    connection.close = function() {
      log("Closing connection...");
      connection.isOpening = false;
      connection.device = null;
      if (connection.isOpen) {
        connection.isOpen = false;
        connection.emit('close');
      } else {
        if (callback) callback(null);
      }
      if (btServer) {
        btServer.disconnect();
        btServer = undefined;
        txCharacteristic = undefined;
        rxCharacteristic = undefined;
      }
    };

    connection.write = function(data, callback) {
      if (data) txDataQueue.push({data:data,callback:callback});
      if (connection.isOpen && !connection.txInProgress) writeChunk();

      function writeChunk() {
        var chunk;
        if (!txDataQueue.length) return;
        var txItem = txDataQueue[0];
        if (txItem.data.length <= CHUNKSIZE) {
          chunk = txItem.data;
          txItem.data = undefined;
        } else {
          chunk = txItem.data.substr(0,CHUNKSIZE);
          txItem.data = txItem.data.substr(CHUNKSIZE);
        }
        connection.txInProgress = true;
        log("BT> Sending "+ JSON.stringify(chunk));
        txCharacteristic.writeValue(str2ab(chunk)).then(function() {
          log("BT> Sent");
          if (!txItem.data) {
            txDataQueue.shift(); // remove this element
            if (txItem.callback) txItem.callback();
          }
          connection.txInProgress = false;
          writeChunk();
        }).catch(function(error) {
         log('BT> SEND ERROR: ' + error);
         txDataQueue = [];
         connection.close();
        });
      }
    };

    // Ideally we could do {filters:[{services:[ NORDIC_SERVICE ]}]}, but it seems that
    // on MacOS there are some problems requesting based on service...
    // https://bugs.chromium.org/p/chromium/issues/detail?id=630598
    navigator.bluetooth.requestDevice({
        filters:[
          { namePrefix: 'Puck.js' },
          { namePrefix: 'Espruino' }
        ], optionalServices: [ NORDIC_SERVICE ]
    }).then(function(device) {
      log('BT>  Device Name:       ' + device.name);
      log('BT>  Device ID:         ' + device.id);
      connection.device = device;
      connection.emit('gotdevice', device);
      device.addEventListener('gattserverdisconnected', function() {
        log("BT> Disconnected (gattserverdisconnected)");
        connection.close();
      });
      return device.gatt.connect();
    }).then(function(server) {
      log("BT> Connected");
      btServer = server;
      return server.getPrimaryService(NORDIC_SERVICE);
    }).then(function(service) {
      log("BT> Got service");
      btService = service;
      return btService.getCharacteristic(NORDIC_RX);
    }).then(function (characteristic) {
      rxCharacteristic = characteristic;
      log("BT> Got Rx characteristic");
      rxCharacteristic.addEventListener('characteristicvaluechanged', function(event) {
        var value = event.target.value.buffer; // get arraybuffer
        connection.emit('data', ab2str(value));
      });
      return rxCharacteristic.startNotifications();
    }).then(function() {
      log("BT> Established Rx characteristic listener")
      return btService.getCharacteristic(NORDIC_TX);
    }).then(function (characteristic) {
      log("BT> Got Tx characteristic");
      if (!characteristic) {
        throw TypeError('Tx characteristic is falsey!');
      }
      txCharacteristic = characteristic;
      log("BT> txCharacteristic: " + txCharacteristic);
      connection.txInProgress = false;
      connection.isOpen = true;
      connection.isOpening = false;
      callback(connection);
      log("BT> open handler: " + connection["onopen"]);
      connection.emit('open');
      // if we had any writes queued, do them now
      connection.write();
    }).catch(function(error) {
      log('BT> ERROR: ' + error);
      connection.close();
      callback(null);
    });
    return connection;
  };

  // ----------------------------------------------------------
  var connection;
  /* convenience function... Write data, call the callback with data:
       callbackNewline = false => if no new data received for ~0.5 sec
       callbackNewline = true => after a newline */
  function write(data, callback, callbackNewline) {
    var cbTimeout;
    function onWritten() {
      isWriting = false;
      if (callback) {
        if (callbackNewline) {
          connection.cb = function(d) {
            var newLineIdx = connection.received.indexOf("\n");
            if (newLineIdx>=0) {
              var l = connection.received.substr(0,newLineIdx);
              connection.received = connection.received.substr(newLineIdx+1);
              connection.cb = undefined;
              if (cbTimeout) clearTimeout(cbTimeout);
              cbTimeout = undefined;
              if (callback)
                callback(l);
            }
          };
        }
        // wait for any received data if we have a callback...
        var waitTime = 10;
        var maxTime = waitTime;
        cbTimeout = setTimeout(function timeout() {
          cbTimeout = undefined;
          if ((connection.hadData || maxTime==waitTime) && maxTime--) {
            cbTimeout = setTimeout(timeout, 250);
          } else {
            connection.cb = undefined;
            if (callback)
              callback(connection.received);
            connection.received = "";
          }
          connection.hadData = false;
        }, 250);
      } else connection.received = "";
    }

    if (connection && (connection.isOpen || connection.isOpening)) {
      log("Connection OK to receive data... write to it.");
      if (!connection.txInProgress) connection.received = "";
      return connection.write(data, onWritten);
    }

    log("No connection yet, set it up...");
    connection = connect(function(puck) {
      if (!puck) {
        connection = undefined;
        if (callback) callback(null);
        return;
      }
      connection.received = "";
      connection.on('data', function(d) {
        connection.received += d;
        connection.hadData = true;
        if (connection.cb)  connection.cb(d);
      });
      connection.on('close', function(d) {
        connection = undefined;
      });
    });
    connection.write(data, onWritten);
  }

  // ----------------------------------------------------------

  var puck = {
    /// Are we writing debug information?
    debug : false,
    /// Used internally to write log information - you can replace this with your own function
    log : function(s) { if (this.debug) console.log(s)},
    /** Connect to a new device - this creates a separate
     connection to the one `write` and `eval` use. */
    connect : connect,
    /// Write to Puck.js and call back when the data is written.  Creates a connection if it doesn't exist
    write : write,
    /// Evaluate an expression and call cb with the result. Creates a connection if it doesn't exist
    eval : function(expr, cb) {
      write('\x10Bluetooth.println(JSON.stringify('+expr+'))\n', function(d) {
        if (d!==null) cb(JSON.parse(d)); else cb(null);
      }, true);
    },
    /// Did `write` and `eval` manage to create a connection?
    isConnected : function() {
      return connection!==undefined;
    },
    /// get the connection used by `write` and `eval`
    getConnection : function() {
      return connection;
    },
    /// Close the connection used by `write` and `eval`
    close : function() {
      if (connection)
        connection.close();
    }
  };
  return puck;
})();
