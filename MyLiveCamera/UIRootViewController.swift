//
//  UIRootViewController.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/21.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import UIKit

class UIRootViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let videoVC = MainVideoViewContorller()
        self.addChild(videoVC)
        self.view.addSubview(videoVC.view)
        
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
            return .landscape
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
