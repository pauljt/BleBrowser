//
//  Jsonifiable.swift
//  BleBrowser
//
//  Copyright © 2017 David Park. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreBluetooth


protocol Jsonifiable {
    func jsonify() -> String
}
extension Double: Jsonifiable {
    func jsonify() -> String {
        return self.description
    }
}
extension Int: Jsonifiable {
    func jsonify() -> String {
        return self.description
    }
}
extension String: Jsonifiable {
    func jsonify() -> String {
        var str = self
        for (bad, replacement) in [
            ("\\", "\\\\"), ("\n", "\\n"), ("\t", "\\t"), ("\r", "\\r"),
            ("\"", "\\\""), ("\u{2028}", ""), ("\u{2029}", "")] {
                str = str.replacingOccurrences(of: bad, with: replacement)
        }
        return "\"\(str)\""
    }
}
extension CBUUID: Jsonifiable {
    func jsonify() -> String {
        return "\"\(self.uuidString)\""
    }
}
extension Array: Jsonifiable {
    func jsonify() -> String {
        return "[\(self.map{($0 as! Jsonifiable).jsonify()}.joined(separator: ", "))]"
    }
}

extension Dictionary: Jsonifiable {
    func jsonify() -> String {
        var json = "{"
        for (key, val) in self {
            // Unfortunately because Swift does not yet support type constraints on a protocol extension, we have to do a runtime check that val is Jsonifiable and key is a String.
            let skey = key as! String
            let jval = val as! Jsonifiable
            if !json.isEmpty {
                json.append(", ")
            }
            json.append("\(skey.jsonify()): \(jval.jsonify())")
        }
        json.append("}")
        return json
    }
}

extension Data: Jsonifiable {
    func jsonify() -> String {
        return "\"\(self.base64EncodedString(options:Data.Base64EncodingOptions(rawValue: 0)))\""
    }
}
