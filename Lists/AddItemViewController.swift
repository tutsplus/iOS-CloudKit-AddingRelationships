//
//  AddItemViewController.swift
//  Lists
//
//  Created by Bart Jacobs on 29/11/15.
//  Copyright © 2015 Tuts+. All rights reserved.
//

import UIKit
import CloudKit
import SVProgressHUD

protocol AddItemViewControllerDelegate {
    func controller(controller: AddItemViewController, didAddItem item: CKRecord)
    func controller(controller: AddItemViewController, didUpdateItem item: CKRecord)
}

class AddItemViewController: UIViewController {
    
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var numberStepper: UIStepper!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    var delegate: AddItemViewControllerDelegate?
    var newItem: Bool = true
    
    var list: CKRecord!
    var item: CKRecord?
    
    // MARK: -
    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        
        // Update Helper
        newItem = item == nil
        
        // Add Observer
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "textFieldTextDidChange:", name: UITextFieldTextDidChangeNotification, object: nameTextField)
    }
    
    override func viewDidAppear(animated: Bool) {
        nameTextField.becomeFirstResponder()
    }
    
    // MARK: -
    // MARK: View Methods
    private func setupView() {
        updateNameTextField()
        updateNumberStepper()
        updateSaveButton()
    }
    
    // MARK: -
    private func updateNameTextField() {
        if let name = item?.objectForKey("name") as? String {
            nameTextField.text = name
        }
    }
    
    // MARK: -
    private func updateNumberStepper() {
        if let number = item?.objectForKey("number") as? Double {
            numberStepper.value = number
        }
    }

    // MARK: -
    private func updateSaveButton() {
        let text = nameTextField.text
        
        if let name = text {
            saveButton.enabled = !name.isEmpty
        } else {
            saveButton.enabled = false
        }
    }
    
    // MARK: -
    // MARK: Actions
    @IBAction func cancel(sender: AnyObject) {
        navigationController?.popViewControllerAnimated(true)
    }
    
    @IBAction func save(sender: AnyObject) {
        // Helpers
        let name = nameTextField.text
        let number = Int(numberStepper.value)
        
        // Fetch Private Database
        let privateDatabase = CKContainer.defaultContainer().privateCloudDatabase
        
        if item == nil {
            // Create Record
            item = CKRecord(recordType: RecordTypeItems)
            
            // Initialize Reference
            let listReference = CKReference(recordID: list.recordID, action: .DeleteSelf)
            
            // Configure Record
            item?.setObject(listReference, forKey: "list")
        }
        
        // Configure Record
        item?.setObject(name, forKey: "name")
        item?.setObject(number, forKey: "number")
        
        // Show Progress HUD
        SVProgressHUD.show()
        
        // Save Record
        privateDatabase.saveRecord(item!) { (record, error) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                // Dismiss Progress HUD
                SVProgressHUD.dismiss()
                
                // Process Response
                self.processResponse(record, error: error)
            })
        }
    }

    @IBAction func numberDidChange(sender: UIStepper) {
        let number = Int(sender.value)
        
        // Update Number Label
        numberLabel.text = "\(number)"
    }

    // MARK: -
    // MARK: Notification Handling
    func textFieldTextDidChange(notification: NSNotification) {
        updateSaveButton()
    }
    
    // MARK: -
    // MARK: Helper Methods
    private func processResponse(record: CKRecord?, error: NSError?) {
        var message = ""
        
        if let error = error {
            print(error)
            message = "We were not able to save your item."
            
        } else if record == nil {
            message = "We were not able to save your item."
        }
        
        if !message.isEmpty {
            // Initialize Alert Controller
            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
            
            // Present Alert Controller
            presentViewController(alertController, animated: true, completion: nil)
            
        } else {
            // Notify Delegate
            if newItem {
                delegate?.controller(self, didAddItem: item!)
            } else {
                delegate?.controller(self, didUpdateItem: item!)
            }
            
            // Pop View Controller
            navigationController?.popViewControllerAnimated(true)
        }
    }

}
