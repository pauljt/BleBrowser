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
        self.navigationItem.rightBarButtonItem = self.editButtonItem
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
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bookmark", for: indexPath)

        cell.textLabel?.text = self.bookmarks[indexPath.item].title
        cell.detailTextLabel?.text = self.bookmarks[indexPath.item].url.absoluteString

        return cell
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let srci = indexPath.item
        switch editingStyle {
        case .delete:
            self.tableView.beginUpdates()
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.bookmarks.remove(at: srci)
            self.tableView.endUpdates()
        default: break
            
        }
    }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let srci = sourceIndexPath.item
        let dsti = destinationIndexPath.item

        let bm = self.bookmarks.remove(at: srci)
        self.bookmarks.insert(bm, at: dsti)

    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.bookmarks.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
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
