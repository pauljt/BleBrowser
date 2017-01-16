//
//  WBBookmark.swift
//  BleBrowser
//
//  Created by David Park on 13/01/2017.
//  Copyright © 2017 David Park. All rights reserved.
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
}
