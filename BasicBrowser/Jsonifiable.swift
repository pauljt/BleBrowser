//
//  Jsonifiable.swift
//  BleBrowser
//
//  Copyright © 2016 David Park. All rights reserved.
//

import Foundation


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
extension Array: Jsonifiable {
    func jsonify() -> String {
        var json = "["
        for val in self {
            // Need this as per comment below.
            let jval = val as! Jsonifiable
            if !json.isEmpty {
                json.append(", ")
            }
            json.append(jval.jsonify())
        }
        json.append("]")
        return json
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
