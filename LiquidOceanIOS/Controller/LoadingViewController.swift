//
//  LoadingViewController.swift
//  LiquidOceanIOS
//
//  Created by Eric Versteeg on 2/10/21.
//  Copyright © 2021 Eric Versteeg. All rights reserved.
//

import UIKit
import Alamofire

class LoadingViewController: UIViewController, InteractiveCanvasSocketConnectionDelegate {

    var showInteractiveCanvas = "ShowInteractiveCanvas"
    
    @IBOutlet var connectingLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    
    @IBOutlet weak var dotsLabel: UILabel!
    @IBOutlet weak var gameTipLabel: UILabel!
    
    @IBOutlet weak var connectingLabelWidth: NSLayoutConstraint!
    
    @IBOutlet weak var artView: ArtView!
    
    @IBOutlet weak var topContributorName1: UILabel!
    @IBOutlet weak var topContributorName2: UILabel!
    @IBOutlet weak var topContributorName3: UILabel!
    @IBOutlet weak var topContributorName4: UILabel!
    @IBOutlet weak var topContributorName5: UILabel!
    @IBOutlet weak var topContributorName6: UILabel!
    @IBOutlet weak var topContributorName7: UILabel!
    @IBOutlet weak var topContributorName8: UILabel!
    @IBOutlet weak var topContributorName9: UILabel!
    @IBOutlet weak var topContributorName10: UILabel!
    
    @IBOutlet weak var topContributorAmt1: UILabel!
    @IBOutlet weak var topContributorAmt2: UILabel!
    @IBOutlet weak var topContributorAmt3: UILabel!
    @IBOutlet weak var topContributorAmt4: UILabel!
    @IBOutlet weak var topContributorAmt5: UILabel!
    @IBOutlet weak var topContributorAmt6: UILabel!
    @IBOutlet weak var topContributorAmt7: UILabel!
    @IBOutlet weak var topContributorAmt8: UILabel!
    @IBOutlet weak var topContributorAmt9: UILabel!
    @IBOutlet weak var topContributorAmt10: UILabel!
    
    let gameTips = ["You can turn several features on / off in the Options menu.",
                    "All drawings can be exported to a PNG file. Simply choose the object selector tool in the toolbox, tap an object, then select the share or save feature.",
                    "Anything you create on the world canvas is automatically saved and shared with others.",
                    "Like you level, paint, and other stas? Back your account up and sync across multiple devices with an access pincode.",
                    "Tap on any pixel on the world canvas to view a history of edits for that position.",
                    "No racism, harassment, or hate speech is allowed on the world canvas.",
                    "Anyone can get started painting on the world canvas in 5 minutes or less. Simply wait for the next Paint Cycle.",
                    "Tap the bottom corner of the screen while drawing to bring up many recently used colors."]
    
    var errorTypeServer = "server"
    var errorTypeSocket = "socket"
    
    var doneLoadingPixels = false
    var doneSyncDevice = false
    var doneLoadingTopContributors = false
    
    var doneLoadingChunk1 = false
    var doneLoadingChunk2 = false
    var doneLoadingChunk3 = false
    var doneLoadingChunk4 = false
    
    var doneConnectingSocket = false
    
    var timer: Timer!
    var lastDotsStr = ""
    
    var realmId = 0
    
    var showingError = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setBackground()
        
        artView.showBackground = false
        if realmId == 2 {
            artView.jsonFile = "mc_tool_json"
            
            connectingLabel.text = "Connecting to dev server"
            connectingLabelWidth.constant -= 30
            
            downloadCanvasPixels()
        }
        else {
            artView.jsonFile = "globe_json"
            
            downloadCanvasChunkPixels()
        }

        if SessionSettings.instance.sentUniqueId {
            getDeviceInfo()
        }
        else {
            sendDeviceId()
        }
        
        getTopContributors()
        
        InteractiveCanvasSocket.instance.startSocket()
        InteractiveCanvasSocket.instance.socketConnectionDelegate = self
        
        SessionSettings.instance.updateShortTermPixels()
        
        let rIndex = Int(arc4random() % UInt32(gameTips.count))
        gameTipLabel.text = gameTips[rIndex]
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { (tmr) in
            if self.lastDotsStr.count < 3 {
                self.lastDotsStr = self.lastDotsStr + "."
            }
            else {
                self.lastDotsStr = ""
            }
            self.dotsLabel.text = self.lastDotsStr
        }
        
        if realmId == 1 {
            statusLabel.text = String(format: "Loading %d / 7", getNumLoaded())
        }
        else {
            statusLabel.text = String(format: "Loading %d / 4", getNumLoaded())
        }
    }
    
    func downloadCanvasChunkPixels() {
        URLSessionHandler.instance.downloadCanvasChunkPixels(chunk: 1) { (success) in
            if success {
                self.doneLoadingChunk1 = true
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
        URLSessionHandler.instance.downloadCanvasChunkPixels(chunk: 2) { (success) in
            if success {
                self.doneLoadingChunk2 = true
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
        URLSessionHandler.instance.downloadCanvasChunkPixels(chunk: 3) { (success) in
            if success {
                self.doneLoadingChunk3 = true
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
        URLSessionHandler.instance.downloadCanvasChunkPixels(chunk: 4) { (success) in
            if success {
                self.doneLoadingChunk4 = true
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
    }

    func downloadCanvasPixels() {
        
        URLSessionHandler.instance.downloadCanvasPixels { (success) in
            if success {
                self.doneLoadingPixels = true
                
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
    }
    
    func getTopContributors() {
        URLSessionHandler.instance.downloadTopContributors { (topContributors) in
            let topContributorNameViews1 = [self.topContributorName1, self.topContributorName2, self.topContributorName3, self.topContributorName4, self.topContributorName5]
            let topContributorNameViews2 = [self.topContributorName6, self.topContributorName7, self.topContributorName8, self.topContributorName9, self.topContributorName10]
            
            let topContributorAmtViews1 = [self.topContributorAmt1, self.topContributorAmt2, self.topContributorAmt3, self.topContributorAmt4, self.topContributorAmt5]
            let topContributorAmtViews2 = [self.topContributorAmt6, self.topContributorAmt7, self.topContributorAmt8, self.topContributorAmt9, self.topContributorAmt10]
            
            if topContributors != nil {
                for i in topContributors!.indices {
                    let topContributor = topContributors![i]
                    
                    var name = topContributor["name"] as! String
                    
                    if name.count > 10 {
                        name = String(name.prefix(7)) + "..."
                    }
                    
                    let amt = topContributor["amt"] as! Int
                    
                    if i == 0 {
                        SessionSettings.instance.firstContributorName = name
                        self.topContributorName1.textColor = Utils.UIColorFromColorHex(hex: "0xffdecb52")
                    }
                    else if i == 1 {
                        SessionSettings.instance.secondContributorName = name
                        self.topContributorName2.textColor = Utils.UIColorFromColorHex(hex: "0xffafb3b1")
                    }
                    else if i == 2 {
                        SessionSettings.instance.thirdContributorName = name
                        self.topContributorName3.textColor = Utils.UIColorFromColorHex(hex: "0xffbd927b")
                    }
                    
                    if i < 5 {
                        topContributorNameViews1[i]!.text = name
                        topContributorAmtViews1[i]!.text = String(amt)
                        
                        topContributorNameViews1[i]!.isHidden = false
                        topContributorAmtViews1[i]!.isHidden = false
                        
                        topContributorNameViews1[i]!.alpha = 0
                        topContributorAmtViews1[i]!.alpha = 0
                        
                        UIView.animate(withDuration: 0.5) {
                            topContributorNameViews1[i]!.alpha = 1
                            topContributorAmtViews1[i]!.alpha = 1
                        }
                    }
                    else {
                        topContributorNameViews2[i - 5]!.text = name
                        topContributorAmtViews2[i - 5]!.text = String(amt)
                        
                        topContributorNameViews2[i - 5]!.isHidden = false
                        topContributorAmtViews2[i - 5]!.isHidden = false
                        
                        topContributorNameViews2[i - 5]!.alpha = 0
                        topContributorAmtViews2[i - 5]!.alpha = 0
                        
                        UIView.animate(withDuration: 0.5) {
                            topContributorNameViews2[i - 5]!.alpha = 1
                            topContributorAmtViews2[i - 5]!.alpha = 1
                        }
                    }
                }
                
                self.doneLoadingTopContributors = true
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
    }
    
    func getDeviceInfo() {
        URLSessionHandler.instance.getDeviceInfo { (success) -> (Void) in
            if success {
                self.doneSyncDevice = true
                
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
    }
    
    func sendDeviceId() {
        URLSessionHandler.instance.sendDeviceId { (success) -> (Void) in
            if success {
                self.doneSyncDevice = true
                
                self.downloadFinished()
            }
            else {
                self.showError(type: self.errorTypeServer)
            }
        }
    }
    
    func downloadFinished() {
        if realmId == 1 {
            statusLabel.text = String(format: "Loading %d / 7", getNumLoaded())
        }
        else {
            statusLabel.text = String(format: "Loading %d / 4", getNumLoaded())
        }
        
        if loadingDone() {
            SessionSettings.instance.save()
            self.performSegue(withIdentifier: self.showInteractiveCanvas, sender: nil)
        }
    }
    
    func getNumLoaded() -> Int {
        var num = 0
        
        if doneLoadingPixels {
            num += 1
        }
        
        if doneSyncDevice {
            num += 1
        }
        
        if doneLoadingTopContributors {
            num += 1
        }
        
        if doneLoadingChunk1 {
            num += 1
        }
        
        if doneLoadingChunk2 {
            num += 1
        }
        
        if doneLoadingChunk3 {
            num += 1
        }
        
        if doneLoadingChunk4 {
            num += 1
        }
        
        if doneConnectingSocket {
            num += 1
        }
        
        return num
    }
    
    func loadingDone() -> Bool {
        if realmId == 1 {
            return doneSyncDevice && doneLoadingTopContributors && doneLoadingChunk1 &&
                doneLoadingChunk2 && doneLoadingChunk3 && doneLoadingChunk4 &&
                doneConnectingSocket
        }
        else {
            return doneLoadingPixels && doneSyncDevice && doneLoadingTopContributors &&
                doneConnectingSocket
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == self.showInteractiveCanvas {
            let vc = segue.destination as! InteractiveCanvasViewController
            vc.world = true
            vc.realmId = realmId
        }
        
        timer.invalidate()
    }
    
    func setBackground() {
        let gradient = CAGradientLayer()

        gradient.frame = view.bounds
        gradient.colors = [UIColor(argb: Utils.int32FromColorHex(hex: "0xff000000")).cgColor, UIColor(argb: Utils.int32FromColorHex(hex: "0xff333333")).cgColor]
        
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0, y: 1)

        view.layer.insertSublayer(gradient, at: 0)
    }
    
    func showError(type: String) {
        if !showingError {
            var msg = ""
            
            if type == errorTypeServer {
                msg = "Oops, could not find world pixel data. Please try again"
            }
            else if type == errorTypeSocket {
                msg = "Socket connection error"
            }
            
            // create the alert
            let alert = UIAlertController(title: nil, message: msg, preferredStyle: UIAlertController.Style.alert)
            // add the actions (buttons)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { action in
                InteractiveCanvasSocket.instance.socketConnectionDelegate = nil
                
                self.performSegue(withIdentifier: "UnwindToMenu", sender: nil)
            }))
            // show the alert
            self.present(alert, animated: true, completion: nil)
            
            showingError = true
        }
    }
    
    // socket connection delegate
    func notifySocketConnect() {
        doneConnectingSocket = true
        InteractiveCanvasSocket.instance.socketConnectionDelegate = nil
    }
    
    func notifySocketConnectionError() {
        showError(type: errorTypeSocket)
    }
}
