//
//  ListViewController.swift
//  Lists
//
//  Created by Bart Jacobs on 29/11/15.
//  Copyright © 2015 Tuts+. All rights reserved.
//

import UIKit
import CloudKit
import SVProgressHUD

let SegueItemDetail = "ItemDetail"

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AddItemViewControllerDelegate {
    
    static let ItemCell = "ItemCell"
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    var list: CKRecord!
    var items = [CKRecord]()
    
    var selection: Int?
    
    // MARK: -
    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set Title
        title = list.objectForKey("name") as? String
        
        setupView()
        fetchItems()
    }
    
    // MARK: -
    // MARK: Segue Life Cycle
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard let identifier = segue.identifier else { return }
        
        switch identifier {
        case SegueItemDetail:
            // Fetch Destination View Controller
            let addItemViewController = segue.destinationViewController as! AddItemViewController
            
            // Configure View Controller
            addItemViewController.list = list
            addItemViewController.delegate = self
            
            if let selection = selection {
                // Fetch Item
                let item = items[selection]
                
                // Configure View Controller
                addItemViewController.item = item
            }
        default:
            break
        }
    }

    // MARK: -
    // MARK: Table View Data Source Methods
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // Dequeue Reusable Cell
        let cell = tableView.dequeueReusableCellWithIdentifier(ListViewController.ItemCell, forIndexPath: indexPath)
        
        // Configure Cell
        cell.accessoryType = .DetailDisclosureButton
        
        // Fetch Record
        let item = items[indexPath.row]
        
        if let itemName = item.objectForKey("name") as? String {
            // Configure Cell
            cell.textLabel?.text = itemName
            
        } else {
            cell.textLabel?.text = "-"
        }
        
        if let itemNumber = item.objectForKey("number") as? Int {
            // Configure Cell
            cell.detailTextLabel?.text = "\(itemNumber)"
            
        } else {
            cell.detailTextLabel?.text = "1"
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard editingStyle == .Delete else { return }
        
        // Fetch Record
        let item = items[indexPath.row]
        
        // Delete Record
        deleteRecord(item)
    }

    // MARK: -
    // MARK: Table View Delegate Methods
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        // Save Selection
        selection = indexPath.row
        
        // Perform Segue
        performSegueWithIdentifier(SegueItemDetail, sender: self)
    }

    // MARK: -
    // MARK: Add Item View Controller Delegate Methods
    func controller(controller: AddItemViewController, didAddItem item: CKRecord) {
        // Add Item to Items
        items.append(item)
        
        // Sort Items
        sortItems()
        
        // Update Table View
        tableView.reloadData()
        
        // Update View
        updateView()
    }
    
    func controller(controller: AddItemViewController, didUpdateItem item: CKRecord) {
        // Sort Items
        sortItems()
        
        // Update Table View
        tableView.reloadData()
    }
    
    // MARK: -
    // MARK: View Methods
    private func setupView() {
        tableView.hidden = true
        messageLabel.hidden = true
        activityIndicatorView.startAnimating()
    }
    
    private func updateView() {
        let hasRecords = items.count > 0
        
        tableView.hidden = !hasRecords
        messageLabel.hidden = hasRecords
        activityIndicatorView.stopAnimating()
    }

    // MARK: -
    // MARK: Helper Methods
    private func fetchItems() {
        // Fetch Private Database
        let privateDatabase = CKContainer.defaultContainer().privateCloudDatabase
        
        // Initialize Query
        let reference = CKReference(recordID: list.recordID, action: .DeleteSelf)
        let query = CKQuery(recordType: RecordTypeItems, predicate: NSPredicate(format: "list == %@", reference))
        
        // Configure Query
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Perform Query
        privateDatabase.performQuery(query, inZoneWithID: nil) { (records, error) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // Process Response on Main Thread
                self.processResponseForQuery(records, error: error)
            })
        }
    }
    
    private func processResponseForQuery(records: [CKRecord]?, error: NSError?) {
        var message = ""
        
        if let error = error {
            print(error)
            message = "Error Fetching Items for List"
            
        } else if let records = records {
            items = records
            
            if items.count == 0 {
                message = "No Items Found"
            }
            
        } else {
            message = "No Items Found"
        }
        
        if message.isEmpty {
            tableView.reloadData()
        } else {
            messageLabel.text = message
        }
        
        updateView()
    }
    
    // MARK: -
    private func deleteRecord(item: CKRecord) {
        // Fetch Private Database
        let privateDatabase = CKContainer.defaultContainer().privateCloudDatabase
        
        // Show Progress HUD
        SVProgressHUD.show()
        
        // Delete List
        privateDatabase.deleteRecordWithID(item.recordID) { (recordID, error) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // Dismiss Progress HUD
                SVProgressHUD.dismiss()
                
                // Process Response
                self.processResponseForDeleteRequest(item, recordID: recordID, error: error)
            })
        }
    }

    private func processResponseForDeleteRequest(record: CKRecord, recordID: CKRecordID?, error: NSError?) {
        var message = ""
        
        if let error = error {
            print(error)
            message = "We are unable to delete the item."
            
        } else if recordID == nil {
            message = "We are unable to delete the item."
        }
        
        if message.isEmpty {
            // Calculate Row Index
            let index = items.indexOf(record)
            
            if let index = index {
                // Update Data Source
                items.removeAtIndex(index)
                
                if items.count > 0 {
                    // Update Table View
                    tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Right)
                    
                } else {
                    // Update Message Label
                    messageLabel.text = "No Items Found"
                    
                    // Update View
                    updateView()
                }
            }
            
        } else {
            // Initialize Alert Controller
            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
            
            // Present Alert Controller
            presentViewController(alertController, animated: true, completion: nil)
        }
    }

    private func sortItems() {
        items.sortInPlace {
            var result = false
            let name0 = $0.objectForKey("name") as? String
            let name1 = $1.objectForKey("name") as? String
            
            if let itemName0 = name0, itemName1 = name1 {
                result = itemName0.localizedCaseInsensitiveCompare(itemName1) == .OrderedAscending
            }
            
            return result
        }
    }

}
