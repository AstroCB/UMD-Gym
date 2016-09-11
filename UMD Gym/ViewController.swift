//
//  ViewController.swift
//  UMD Gym
//
//  Created by Cameron Bernhardt on 9/5/16.
//  Copyright © 2016 Cameron Bernhardt. All rights reserved.
//

import UIKit
import MessageUI

/**
 
 Handles JSON in an OO/JavaScript-y fashion
 
 # Example usage
 `let json: JSON = JSON(url: "https://me.com/me.json")`
 `print(JSON.parse(json.load()))`
 
 */
public struct JSON {
    var url: String
    /**
     Pulls JSON from the URL provided in the object instantiation
     
     - returns: A `Data` object containing the JSON data if load is successful; `nil` if not
     */
    func load() -> Data? {
        let urlT: URL = URL(string: url)!
        do {
            let data = try Data(contentsOf: urlT)
            return data
        } catch {
            print("Error: " + error.localizedDescription)
            return nil
        }
    }
    
    /**
     Static method for parsing a JSON Data object into an NSDictionary
     
     - parameter data: A Data object in JSON format (see [JSON formatting docs](http://www.json.org))
     - returns: An NSDictionary that can be used to extract data using object:forKey
     */
    static func parse(_ data: Data?) -> NSDictionary {
        if let inputData: Data = data {
            do {
                if let JSON: NSDictionary = try JSONSerialization.jsonObject(with: inputData, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary {
                    return JSON
                }
            } catch {
                print("Parse failed: \((error as NSError).localizedDescription)")
            }
        } else {
            print("Cannot parse invalid data")
        }
        return NSDictionary()
    }
}

extension UIColor {
    convenience init(R: Float, G: Float, B: Float, A: Float) {
        self.init(colorLiteralRed: R/255.0, green: G/255.0, blue: B/255.0, alpha: A)
    }
}

struct StoredColor {
    // UMD red
    var red: Float = 224
    var green: Float = 58
    var blue: Float = 62
}

class ViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet var refresh: UIButton!
    @IBOutlet var percFull: UILabel!
    @IBOutlet var lastUpdated: UILabel!
    
    var bgColor: StoredColor = StoredColor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.loadData()
        self.configureButton()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        DispatchQueue.global().async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            let gymJSON: JSON = JSON(url: "http://recwell.umd.edu/wwwnet/formsite/api/count/GetAreaUsages")
            if let gymData: Data = gymJSON.load() {
                let parsedData: NSDictionary = JSON.parse(gymData)
                
                let gyms: [NSDictionary] = parsedData.object(forKey: "data") as! [NSDictionary]
                var weightRoom: NSDictionary?
                
                for gym in gyms {
                    if let title: String = gym.object(forKey: "title") as? String, title == "ERC Weight Room" {
                        weightRoom = gym
                    }
                }
                
                if let wr: NSDictionary = weightRoom, let wrData: [String: AnyObject] = wr.object(forKey: "latest") as? [String: AnyObject] {
                    // UI Updates
                    DispatchQueue.main.async {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        // Update labels
                        let count: Int = wrData["count"] as! Int
                        var perc: Int = max(0, min(count, 80))/80
                        perc = (perc > 100) ? 100 : perc
                        self.percFull.text = "\(perc)% full"
                        self.lastUpdated.text = "Last updated: \(wrData["time"]!)"
                        
                        // Update button color
                        if let reason: String = wrData["reason"] as? String, let color: String = wrData["usage"] as? String {
                            
                            if perc == 0 && (reason == "Closed" || reason == "N/A") {
                                // Set button to gray if closed
                                self.bgColor = StoredColor(red: 128, green: 128, blue: 128)
                            } else {
                                switch(color) {
                                case "Green":
                                    self.bgColor = StoredColor(red: 0, green: 255, blue: 0)
                                case "Orange":
                                    self.bgColor = StoredColor(red: 255, green: 165, blue: 0)
                                case "Red":
                                    self.bgColor = StoredColor(red: 224, green: 58, blue: 62)
                                default:
                                    print("Color unrecognized: \(color)")
                                }
                            }
                            // Update button color
                            self.reloadColor()
                        }
                    }
                } else {
                    print("Weight room not available")
                    // UI updates
                    DispatchQueue.main.async {
                        self.loadFailed(message: "The ERC weight room was not included in UMD's data. Was it renamed?")
                    }
                }
            } else {
                print("Data unavailable")
                // UI updates
                DispatchQueue.main.async {
                    self.loadFailed(message: "Unable to load data from UMD. Check your network connection, Larry.")
                }
            }
        }
    }
    
    func loadFailed(message: String) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        let alert: UIAlertController = UIAlertController(title: "Load Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Shut up", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Contact Cam", style: .destructive, handler: { (UIAlertAction) in
            // Send email to me
            let mailComposeViewController = self.configuredMailComposeViewController()
            if MFMailComposeViewController.canSendMail() {
                self.present(mailComposeViewController, animated: true, completion: nil)
            } else {
                self.showSendMailErrorAlert()
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func configureButton() {
        self.refresh.sizeToFit()
        self.refresh.layer.cornerRadius = 73.5 // Half of button width
        reloadColor(withAlpha: 0.8)
        self.refresh.layer.borderColor = UIColor(R: 255, G: 213, B: 32, A: 1).cgColor
        self.refresh.clipsToBounds = true
    }
    
    @IBAction func touched(_ sender: UIButton, forEvent event: UIEvent) {
        if let touches: Set = event.allTouches {
            for touch: UITouch in touches {
                self.dealWithTouch(touch)
            }
        }
    }
    
    @IBAction func touchOut(_ sender: AnyObject, forEvent event: UIEvent) {
        if let touches: Set = event.allTouches {
            for touch: UITouch in touches {
                self.dealWithTouch(touch, outside: true)
            }
        }
    }
    
    func dealWithTouch(_ touch: UITouch, outside: Bool = false) {
        let touchTypes: [Int: String] = [0: "touchDown", 3: "touchUpInside"]
        if let type: String = touchTypes[touch.phase.hashValue] {
            if type == "touchDown" { // Initial press
                self.reloadColor()
                self.refresh.layer.borderWidth = 2.0
            } else if type == "touchUpInside" { // User has let go
                self.reloadColor(withAlpha: 0.8)
                self.refresh.layer.borderWidth = 0.0
                if(!outside) {
                    self.loadData()
                } else {
                    self.reloadColor()
                }
            } else {
                print("Unrecognized touch")
            }
        }
    }
    
    func reloadColor(withAlpha alpha: Float = 1) {
        self.refresh.backgroundColor = UIColor(R: bgColor.red, G: bgColor.green, B: bgColor.blue, A: alpha)
        
    }
    
    // MARK: MFMailComposeViewControllerDelegate Method
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func configuredMailComposeViewController() -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self // Extremely important to set the --mailComposeDelegate-- property, NOT the --delegate-- property
        
        mailComposerVC.setToRecipients(["cambernhardt@me.com"])
        mailComposerVC.setSubject("Larry has a problem with the UMD Gym app")
        mailComposerVC.setMessageBody("Here's what's wrong: ", isHTML: false)
        
        return mailComposerVC
    }
    
    func showSendMailErrorAlert() {
        let sendMailErrorAlert = UIAlertController(title: "Could Not Send Email", message: "Your device could not send e-mail.  Please check e-mail configuration and try again.", preferredStyle: .alert)
        sendMailErrorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(sendMailErrorAlert, animated: true, completion: nil)
    }
    
}
