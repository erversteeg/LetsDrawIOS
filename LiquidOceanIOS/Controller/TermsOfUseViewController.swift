//
//  TermsOfUseViewController.swift
//  LiquidOceanIOS
//
//  Created by Eric Versteeg on 8/27/22.
//  Copyright © 2022 Eric Versteeg. All rights reserved.
//

import Foundation
import UIKit

class TermsOfUseViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var agreeLabel: UILabel!
    @IBOutlet weak var agreeSwitch: UISwitch!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var termsOfServiceTextHeight: NSLayoutConstraint!
    
    override func viewDidLayoutSubviews() {
        let h = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude)).height
        
        termsOfServiceTextHeight.constant = h
    }
    
    // scroll view delegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollViewHeight = scrollView.frame.size.height
        let contentHeight = scrollView.contentSize.height
        let scrollOffset = scrollView.contentOffset.y
        
        if scrollOffset + scrollViewHeight >= contentHeight {
            agreeLabel.textColor = UIColor.black
            agreeSwitch.isEnabled = true
        }
    }
    
    @IBAction func agreeSwitchValueChanged(sender: UISwitch) {
        if sender.isOn {
            SessionSettings.instance.agreedToTermsOfService = true
            SessionSettings.instance.saveAgreedToTermsOfService()
            
            self.presentingViewController?.dismiss(animated: false, completion: nil)
            if self.presentingViewController is LoadingViewController {
                (self.presentingViewController as? LoadingViewController)?.processAgreedToTermsOfService()
            }
        }
    }
}
