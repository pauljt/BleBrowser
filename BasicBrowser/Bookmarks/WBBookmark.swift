//
//  WBBookmark.swift
//  BleBrowser
//
//  Created by David Park on 13/01/2017.
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

import UIKit

struct WBBookmark {

    enum keys: String {
        case title, url
    }

    let title: String
    let url: URL

    var dictionary: [String: String] {
        get {
            return [
                WBBookmark.keys.title.rawValue: self.title,
                WBBookmark.keys.url.rawValue: self.url.absoluteString
            ]
        }
    }
    var assumedHTTPSURLPath: String {
        get {
            return self.url.absoluteString.replacingOccurrences(of: "https://", with: "")
        }
    }

    init (title: String, url: URL) {
        self.title = title
        self.url = url
    }

    init? (fromDictionary dictionary: [String: String]) {
        guard
            let title = dictionary[WBBookmark.keys.title.rawValue],
            let urlStr = dictionary[WBBookmark.keys.url.rawValue],
            let url = URL(string: urlStr)
        else {
            return nil
        }
        self.init(title: title, url: url)
    }

    static func == (left: WBBookmark, right: WBBookmark) -> Bool {
        return left.url == right.url
    }
}
