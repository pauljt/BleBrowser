//
//  BookmarksViewController.swift
//  BleBrowser
//
//  Created by David Park on 13/01/2017.
//  Copyright © 2017 David Park. All rights reserved.
//

import UIKit

class BookmarksViewController: UITableViewController {

    // MARK: - Properties
    var bookmarksManager: BookmarksManager!

    // MARK: - Event handling
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.bookmarksManager.saveBookmarks()
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

        cell.textLabel?.text = self.bookmarksManager.bookmarks[indexPath.item].title
        cell.detailTextLabel?.text = self.bookmarksManager.bookmarks[indexPath.item].url.absoluteString

        return cell
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let srci = indexPath.item
        switch editingStyle {
        case .delete:
            self.tableView.beginUpdates()
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.bookmarksManager.bookmarks.remove(at: srci)
            self.tableView.endUpdates()
        default: break
            
        }
    }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let srci = sourceIndexPath.item
        let dsti = destinationIndexPath.item

        let bm = self.bookmarksManager.bookmarks.remove(at: srci)
        self.bookmarksManager.bookmarks.insert(bm, at: dsti)

    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.bookmarksManager.bookmarks.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
}
