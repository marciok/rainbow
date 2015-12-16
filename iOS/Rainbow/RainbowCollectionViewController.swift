//
//  RainbowCollectionViewController.swift
//  Rainbow
//
//  Created by Marcio Klepacz on 09/08/15.
//  Copyright (c) 2015 Marcio Klepacz. All rights reserved.
//

import UIKit
import KFSwiftImageLoader
import SwiftyJSON
import PubNub

class RainbowCollectionViewController: UICollectionViewController {
    var apps: JSON = nil
    var client: PubNub?
    let endPoint = "http://7f32d01e.ngrok.io"
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    required init?(coder aDecoder: NSCoder) {
        let configuration = PNConfiguration(publishKey: "pub-c-2b55a965-bf95-425f-8e3f-3e4cac5689ea", subscribeKey: "sub-c-4e928ca4-9616-11e5-b829-02ee2ddab7fe")
        client = PubNub.clientWithConfiguration(configuration)
        
        super.init(coder: aDecoder)
        client?.addListener(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.startAnimating()
        
        let appsInstalled = Device.appsInstalled()

        self.collectionView?.registerNib(UINib(nibName: "AppCell", bundle: nil), forCellWithReuseIdentifier: "appCell")
        
        let serverURL = NSURL(string: "\(endPoint)/apps")!
        let request = NSMutableURLRequest(URL: serverURL)
        request.addValue("application/json", forHTTPHeaderField: "Content-type")
        request.HTTPMethod = "POST"
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(appsInstalled, options: [])
        } catch {
            print("error parsing JSON")
        }
        
        var requestId: NSString?
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let postAppsDataTask = session.dataTaskWithRequest(request) { (data, response, error) in
            
            requestId = NSString(data: data!, encoding: NSUTF8StringEncoding)
            
            dispatch_async(dispatch_get_main_queue()) {
                self.client?.subscribeToChannels([requestId!], withPresence: true)
            }
        }
        postAppsDataTask.resume()
    }
    
    func hexStringToUIColor (hex: String) -> UIColor {
        var cString: String = hex.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet() as NSCharacterSet).uppercaseString
        
        if (cString.hasPrefix("#")) {
            cString = cString.substringFromIndex(cString.startIndex.advancedBy(1))
        }
        
        if (cString.characters.count != 6) {
            return UIColor.grayColor()
        }
        
        var rgbValue:UInt32 = 0
        NSScanner(string: cString).scanHexInt(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    func fetchAppsSorted(sortId: String) {
        let serverURL = NSURL(string: "\(endPoint)/apps/\(sortId)")!
        let request = NSMutableURLRequest(URL: serverURL)
        request.HTTPMethod = "GET"
        
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let getAppsSortedDataTask = session.dataTaskWithRequest(request) { (data, response, error) in
            self.apps = JSON(data: data!)
            
            dispatch_async(dispatch_get_main_queue()) {
                self.activityIndicatorView.stopAnimating()
                self.collectionView?.reloadData()
            }
        }
        
        getAppsSortedDataTask.resume()
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.apps.count
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.apps[section].count
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        return CGSizeMake(81, 81)
    }
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
            return 0
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(20, 0, 20, 0)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("appCell", forIndexPath: indexPath) as! AppCell
        let urlString = self.apps[indexPath.section][indexPath.row]["image"].stringValue
        cell.imageView.loadImageFromURLString(urlString)
        cell.contentView.backgroundColor = hexStringToUIColor(self.apps[indexPath.section][indexPath.row]["dominant_color"].stringValue)

        return cell
    }
}

//MARK: - PubNub SDK

extension RainbowCollectionViewController:  PNObjectEventListener {
    
    func client(client: PubNub!, didReceiveMessage message: PNMessageResult!) {
        fetchAppsSorted(message.data.subscribedChannel)
    }
}