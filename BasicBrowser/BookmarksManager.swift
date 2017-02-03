//
//  BookmarksManager.swift
//  BleBrowser
//
//  Created by David Park on 03/02/2017.
//  Copyright © 2017 Stefan Arentz. All rights reserved.
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
