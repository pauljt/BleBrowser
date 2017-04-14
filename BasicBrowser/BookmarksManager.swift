//
//  BookmarksManager.swift
//  BleBrowser
//
//  Created by David Park on 03/02/2017.
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

class BookmarksManager {

    // MARK: - Properties
    let userDefaults: UserDefaults
    let key: String
    var bookmarks: [WBBookmark]

    init (userDefaults: UserDefaults, key: String) {
        self.key = key
        self.userDefaults = userDefaults

        let bma = self.userDefaults.array(forKey: key) ?? [Any]()

        var bms = [WBBookmark]()
        for bment in bma {
            guard
                let bmd = bment as? [String: String],
                let bm = WBBookmark(fromDictionary: bmd)
                else {
                    NSLog("Bad entry in bookmarks dict \(bment)")
                    continue
            }
            bms.append(bm)
        }
        self.bookmarks = bms
    }
    func addBookmarks(_ bookmarks: [WBBookmark]) {
        self.bookmarks.append(contentsOf: bookmarks)
        self.userDefaults.set(self.bookmarks.map{$0.dictionary}, forKey: self.key)
    }
    func mergeInBookmarks(bookmarks: [WBBookmark]) {
        let toAdd = bookmarks.filter{bm in !self.bookmarks.contains(where: {$0 == bm})}
        self.addBookmarks(toAdd)
    }
    func mergeInBookmarkDicts(bookmarkDicts: [[String: String]]) {
        let bms = bookmarkDicts.map{WBBookmark(fromDictionary: $0)}.filter{$0 != nil}.map{$0!}
        self.mergeInBookmarks(bookmarks: bms)
    }
    func saveBookmarks() {
        let bms = self.bookmarks.map{$0.dictionary}
        let ud = UserDefaults.standard
        ud.set(bms, forKey: self.key)
        ud.synchronize()
    }
}
