//
//  BookmarksViewController.swift
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

class BookmarksViewController: UITableViewController {

    // MARK: - Properties
    var bookmarksManager: BookmarksManager!

    // MARK: - Event handling
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        let nc = self.navigationController!
        nc.setToolbarHidden(true, animated: true)
        nc.setNavigationBarHidden(false, animated: true)
        nc.hidesBarsOnSwipe = false
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
        cell.detailTextLabel?.text = self.bookmarksManager.bookmarks[indexPath.item].assumedHTTPSURLPath

        return cell
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
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
