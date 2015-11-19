//
//  ViewController.swift
//  Flick Finder
//
//  Created by Jefferson Bonnaire on 16/11/2015.
//  Copyright © 2015 Jefferson Bonnaire. All rights reserved.
//

import UIKit

/* 1 - Define constants */
let BASE_URL = "https://api.flickr.com/services/rest/"
let METHOD_NAME = "flickr.photos.search"
let EXTRAS = "url_m"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"

class ViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var locationSearchButton: UIButton!
    @IBOutlet weak var imageTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var defaultTextLabel: UILabel!
    
    var keys: NSDictionary?
    var methodArguments: [String:String]?
    var API_KEY: String?
    var TEXT: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        
        if let path = NSBundle.mainBundle().pathForResource("Key", ofType: "plist") {
            keys = NSDictionary(contentsOfFile: path)
        }
        
        if let keys = keys {
            API_KEY = keys["API_KEY"] as? String
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        subscribeToKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromKeyboardNotifications()
    }
    
    @IBAction func searchByPhrase(sender: AnyObject) {
        
        guard phraseTextField.text != "" else {
            defaultTextLabel.textColor = UIColor.redColor()
            defaultTextLabel.text = "Please enter a phrase"
            return
        }
        
        /* 2 - API method arguments */
        methodArguments = [
            "method": METHOD_NAME,
            "api_key": API_KEY!,
            "text": phraseTextField.text!,
            "extras": EXTRAS,
            "format": DATA_FORMAT,
            "nojsoncallback": NO_JSON_CALLBACK
        ]
        searchOnFlickApiWithParameters(methodArguments!)
    }
    
    @IBAction func searchByLocation(sender: AnyObject) {
        /* Set boundaries for bbox API min
        The 4 values represent the bottom-left corner of the box and the top-right corner, minimum_longitude, minimum_latitude, maximum_longitude, maximum_latitude
        */
        
        guard longitudeTextField.text != "" && latitudeTextField.text != "" else {
            defaultTextLabel.textColor = UIColor.redColor()
            defaultTextLabel.text = "Please enter both longitute or latitude"
            return
        }
        
        guard -180...180 ~= Int(longitudeTextField.text!)! || -90...90 ~= Int(latitudeTextField.text!)! else {
            defaultTextLabel.textColor = UIColor.redColor()
            defaultTextLabel.text = "Please enter value between -190 and 190 for latitude"
            return
        }
        
        let minlongitudeTextField = Int(longitudeTextField.text!)! * -1
        let minlatitudeTextField =  Int(latitudeTextField.text!)! * -1
        let maxlongitudeTextField = longitudeTextField.text!
        let maxlatitudeTextField = latitudeTextField.text!
                
        /* 2 - API method arguments */
        methodArguments = [
                    "method": METHOD_NAME,
                    "api_key": API_KEY!,
                    "bbox": "\(minlongitudeTextField),\(minlatitudeTextField),\(maxlongitudeTextField),\(maxlatitudeTextField)",
                    "extras": EXTRAS,
                    "format": DATA_FORMAT,
                    "nojsoncallback": NO_JSON_CALLBACK
                ]
                searchOnFlickApiWithParameters(methodArguments!)
    }
    
    func searchOnFlickApiWithParameters(parameters: [String : AnyObject]) {
        
        /* 3 - Initialize session and url */
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(parameters)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        /* 4 - Initialize task for getting data */
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* 5 - Check for a successful response */
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                print("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                if let response = response as? NSHTTPURLResponse {
                    print("Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    print("Your request returned an invalid response! Response: \(response)!")
                } else {
                    print("Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                print("No data was returned by the request!")
                return
            }
            
            /* 6 - Parse the data (i.e. convert the data to JSON and look for values!) */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                print("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary,
                photoArray = photosDictionary["photo"] as? [[String: AnyObject]] else {
                    print("Cannot find keys 'photos' and 'photo' in \(parsedResult)")
                    return
            }
            
            /* GUARD: Is the "total" key in photosDictionary? */
            guard let totalPhotos = (photosDictionary["total"] as? NSString)?.integerValue else {
                print("Cannot find key 'total' in \(photosDictionary)")
                return
            }
            
            if totalPhotos > 0 {
                /* 7 - Generate a random number, then select a random photo */
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
                let photoDictionary = photoArray[randomPhotoIndex] as [String: AnyObject]
                let photoTitle = photoDictionary["title"] as? String /* non-fatal */
                
                /* GUARD: Does our photo have a key for 'url_m'? */
                guard let imageUrlString = photoDictionary["url_m"] as? String else {
                    print("Cannot find key 'url_m' in \(photoDictionary)")
                    return
                }
                
                /* 8 - If an image exists at the url, set the image and title */
                let imageURL = NSURL(string: imageUrlString)
                if let imageData = NSData(contentsOfURL: imageURL!) {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.defaultTextLabel.text = ""
                        self.imageView.image = UIImage(data: imageData)
                        self.imageTitleLabel.text = photoTitle ?? "(Untitled)"
                    })
                } else {
                    print("Image does not exist at \(imageURL)")
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.imageView.image = nil
                    self.defaultTextLabel.text = "Cannot find photos with \(self.TEXT!)"
                })
            }
        }
        
        /* 9 - Resume (execute) the task */
        task.resume()
        
    }
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        view.endEditing(true)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if imageView.image != nil {
            defaultTextLabel.alpha = 0.0
        }
        if view.frame.origin.y == 0.0 {
            view.frame.origin.y -= getKeyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if imageView.image == nil {
            defaultTextLabel.alpha = 1.0
        }
        if view.frame.origin.y != 0.0 {
            view.frame.origin.y += getKeyboardHeight(notification)
        }
    }
    
    func getKeyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
        return keyboardSize.CGRectValue().height
    }
    
    //MARK: Notifications
    func subscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "keyboardWillShow:",
            name: UIKeyboardWillShowNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "keyboardWillHide:",
            name: UIKeyboardWillHideNotification,
            object: nil)
    }
    
    func unsubscribeFromKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: UIKeyboardWillShowNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name:UIKeyboardWillHideNotification,
            object: nil)
    }
}

// MARK: - ViewController (Keyboard Fix)

/* This extension was added as a fix based on student comments */
extension ViewController {
    func dismissAnyVisibleKeyboards() {
        if phraseTextField.isFirstResponder() || latitudeTextField.isFirstResponder() || longitudeTextField.isFirstResponder() {
            self.view.endEditing(true)
        }
    }
}
