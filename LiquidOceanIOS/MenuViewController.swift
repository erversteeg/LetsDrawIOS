//
//  MenuViewController.swift
//  LiquidOceanIOS
//
//  Created by Eric Versteeg on 2/12/21.
//  Copyright © 2021 Eric Versteeg. All rights reserved.
//

import UIKit

class MenuViewController: UIViewController {

    let showLoadingScreen = "ShowLoading"
    
    @IBOutlet weak var playButton: ActionButtonView!
    @IBOutlet weak var optionsButton: ActionButtonView!
    @IBOutlet weak var statsButton: ActionButtonView!
    @IBOutlet weak var exitButton: ActionButtonView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor(argb: Utils.int32FromColorHex(hex: "0xFF333333"))

        self.playButton.type = .play
        self.optionsButton.type = .options
        self.statsButton.type = .stats
        self.exitButton.type = .exit
        
        self.playButton.setOnClickListener {
            self.performSegue(withIdentifier: self.showLoadingScreen, sender: nil)
        }
        
        self.exitButton.setOnClickListener {
            exit(-1)
        }
    }
    
    @IBAction func unwindToViewController(segue: UIStoryboardSegue) {
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
