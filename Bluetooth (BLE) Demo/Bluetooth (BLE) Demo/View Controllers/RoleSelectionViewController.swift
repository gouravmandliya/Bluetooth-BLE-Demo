//
//  BluetoothKit
//
//  Copyright (c) 2015 Rasmus Taulborg Hummelmose - https://github.com/rasmusth
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit


@available(iOS 13.0, *)
internal class RoleSelectionViewController: UIViewController {

    // MARK: Properties

    private let offset = CGFloat(20)
    private let buttonColor = Colors.darkBlue
    @IBOutlet weak var centralButton: UIButton!
    @IBOutlet weak var peripheralButton: UIButton!
    
 

    // MARK: UIViewController Life Cycle

    internal override func viewDidLoad() {
        navigationItem.title = "Select Role"
        view.backgroundColor = UIColor.white
        preparedButtons([ centralButton, peripheralButton ], andAddThemToView: view)
        
        #if os(tvOS)
        peripheralButton.isEnabled = false
        #endif
    }

    // MARK: Functions

    private func preparedButtons(_ buttons: [UIButton], andAddThemToView view: UIView) {
        for button in buttons {
            button.setBackgroundImage(UIImage.imageWithColor(buttonColor), for: UIControl.State())
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
            #if os(iOS)
            button.addTarget(self, action: #selector(RoleSelectionViewController.buttonTapped(_:)), for: UIControl.Event.touchUpInside)
            #elseif os(tvOS)
            button.addTarget(self, action: #selector(RoleSelectionViewController.buttonTapped(_:)), for: UIControl.Event.primaryActionTriggered)
            #endif
        }
    }

    // MARK: Target Actions

    @objc private func buttonTapped(_ button: UIButton) {
        
        if button == centralButton {
            let centralViewController = storyboard?.instantiateViewController(withIdentifier: "BLECentralViewController") as? BLECentralViewController
            navigationController?.pushViewController(centralViewController!, animated: true)
        } else if button == peripheralButton {
            #if os(iOS)
          
            let peripheralViewController = storyboard?.instantiateViewController(withIdentifier: "BLEPeripheralViewController") as? BLEPeripheralViewController

                navigationController?.pushViewController(peripheralViewController!, animated: true)
            #endif
        }
    }

}
