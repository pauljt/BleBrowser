//
//  BookmarksViewController.swift
//  BleBrowser
//
//  Created by David Park on 13/01/2017.
//  Copyright © 2017 David Park. All rights reserved.
//

import UIKit

class BookmarksViewController: UITableViewController {

    enum prefKeys: String {
        case bookmarks
    }

    // MARK: - Properties
    var bookmarks = [WBBookmark]()

    // MARK: - Event handling
    override func viewDidLoad() {
        super.viewDidLoad()

        self.loadBookmarks()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.saveBookmarks()
    }

    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.bookmarks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bookmark", for: indexPath)

        NSLog("indexPath \(indexPath) \(indexPath.item)")
        cell.textLabel?.text = self.bookmarks[indexPath.item].title
        cell.detailTextLabel?.text = self.bookmarks[indexPath.item].url.absoluteString

        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let selectedBookmark = self.bookmarks[indexPath.item]
        _ = self.navigationController?.popViewController(animated: true)
    }

    // MARK: - Private
    private func loadBookmarks() {

        let mb = Bundle.main
        guard let defPlistURL = mb.url(forResource: "Defaults", withExtension: "plist"),
            let defDict = NSDictionary(contentsOf: defPlistURL) else {
                assert(false, "Unexpectedly couldn't find defaults")
        }

        var normedBookmarks = [[String: Any]]()
        defDict.enumerateKeysAndObjects({
            key, object, _ in
            guard
                let strKey = key as? String,
                let pKey = BookmarksViewController.prefKeys(rawValue: strKey)
                else {
                    return
            }

            switch pKey {
            case .bookmarks:
                guard
                    let bdicts = object as? [[String: Any]]
                    else {
                        assert(false, "Unexpectedly couldn't find bookmarks in defaults")
                }
                for bd in bdicts {
                    guard
                        let bdss = bd as? [String: String],
                        let bm = WBBookmark(fromDictionary: bdss)
                        else {
                            assert(false, "bad dictionary array")
                    }
                    normedBookmarks.append(bm.dictionary)
                }
            }
        })

        let normedDefaults = [BookmarksViewController.prefKeys.bookmarks.rawValue: normedBookmarks]
        let ud = UserDefaults.standard
        ud.register(defaults: normedDefaults)

        let bma = ud.array(forKey: BookmarksViewController.prefKeys.bookmarks.rawValue) ?? [Any]()

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
    private func saveBookmarks() {
        let bms = self.bookmarks.map{$0.dictionary}
        let ud = UserDefaults.standard
        ud.set(bms, forKey: BookmarksViewController.prefKeys.bookmarks.rawValue)
        ud.synchronize()
    }
}
