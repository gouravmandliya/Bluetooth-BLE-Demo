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


class BLEPeripheralViewController: UIViewController, AvailabilityViewController, BKPeripheralDelegate, LoggerDelegate, BKRemotePeerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
   
    // MARK: Properties

    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var receiverImageView: UIImageView!
    @IBOutlet weak var pickImageButton: UIButton!

    internal var availabilityView = AvailabilityView()

    private let peripheral = BKPeripheral()

    private lazy var sendDataBarButtonItem: UIBarButtonItem! = { UIBarButtonItem(title: "Send Data", style: UIBarButtonItem.Style.plain, target: self, action: #selector(BLEPeripheralViewController.sendData)) }()

    // MARK: UIViewController Life Cycle

     override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Peripheral"
        view.backgroundColor = UIColor.white
        Logger.delegate = self
        // applyAvailabilityView()
        logTextView.isEditable = false
        logTextView.alwaysBounceVertical = true
        startPeripheral()
        sendDataBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = sendDataBarButtonItem
        pickImageButton.addTarget(self, action: #selector(BLEPeripheralViewController.pickImage), for: .touchUpInside)
    }

    deinit {
        _ = try? peripheral.stop()
    }

    // MARK: Functions


    
    func applyAvailabilityView() {
        
    }

    private func startPeripheral() {
        do {
            peripheral.delegate = self
            peripheral.addAvailabilityObserver(self)
            let dataServiceUUID = UUID(uuidString: "6E6B5C64-FAF7-40AE-9C21-D4933AF45B23")!
            let dataServiceCharacteristicUUID = UUID(uuidString: "477A2967-1FAB-4DC5-920A-DEE5DE685A3D")!
            let localName = Bundle.main.infoDictionary!["CFBundleName"] as? String
            let configuration = BKPeripheralConfiguration(dataServiceUUID: dataServiceUUID, dataServiceCharacteristicUUID: dataServiceCharacteristicUUID, localName: localName)
            try peripheral.startWithConfiguration(configuration)
            Logger.log("Awaiting connections from remote centrals")
        } catch let error {
            print("Error starting: \(error)")
        }
    }

    private func refreshControls() {
        sendDataBarButtonItem.isEnabled = peripheral.connectedRemoteCentrals.count > 0
    }

    // MARK: Target Actions

    @objc private func sendData() {
//        let numberOfBytesToSend: Int = Int(arc4random_uniform(950) + 50)
//        // let data = Data.dataWithNumberOfBytes(numberOfBytesToSend)
//        var data = Data()
//        if let img = UIImage(named: "demo.jpeg") {
//            data = img.pngData() ?? Data()
//        }
        guard let data = receiverImageView.image?.compress(to: 300) else { return }
       // Logger.log("Prepared \(numberOfBytesToSend) bytes with MD5 hash: \(data.md5().toHexString())")
        IHProgressHUD.show(withStatus: "Sending data to peripheral...")
        

        for remoteCentral in peripheral.connectedRemoteCentrals {
            Logger.log("Sending to \(remoteCentral)")
            peripheral.sendData(data, toRemotePeer: remoteCentral) { _, remoteCentral, error in
                guard error == nil else {
                    IHProgressHUD.showError(withStatus: "Failed sending to \(remoteCentral)")
                    Logger.log("Failed sending to \(remoteCentral)")
                    return
                }
                IHProgressHUD.showSuccesswithStatus("Success")
                Logger.log("Sent to \(remoteCentral)")
            }
        }
    }

    // MARK: BKPeripheralDelegate

    internal func peripheral(_ peripheral: BKPeripheral, remoteCentralDidConnect remoteCentral: BKRemoteCentral) {
        Logger.log("Remote central did connect: \(remoteCentral)")
        remoteCentral.delegate = self
        refreshControls()
    }

    internal func peripheral(_ peripheral: BKPeripheral, remoteCentralDidDisconnect remoteCentral: BKRemoteCentral) {
        Logger.log("Remote central did disconnect: \(remoteCentral)")
        refreshControls()
    }

    // MARK: BKRemotePeerDelegate

    func remotePeer(_ remotePeer: BKRemotePeer, didSendArbitraryData data: Data) {
      //  Logger.log("Received data of length: \(data.count) with hash: \(data.md5().toHexString())")
        let image = UIImage(data: data)
        print(image)
        receiverImageView.image = image
    }

    @objc private func pickImage() {
        let imagePickerController = UIImagePickerController()
          imagePickerController.allowsEditing = false // If you want edit option set "true"
          imagePickerController.sourceType = .photoLibrary
          imagePickerController.delegate = self
          present(imagePickerController, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let tempImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        receiverImageView.image  = tempImage

//        remotePeripheral.sendData(tempImage.pngData() ?? Data(), toRemotePeer: central) { _, remoteCentral, error in
//            guard error == nil else {
//                Logger.log("Failed sending to \(remoteCentral)")
//                return
//            }
//            Logger.log("Sent to \(remoteCentral)")
//        }
        self.dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: LoggerDelegate

    internal func loggerDidLogString(_ string: String) {
        if logTextView.text.count > 0 {
            logTextView.text = "\(logTextView.text ?? "") \n \(string)"
        } else {
            logTextView.text = string
        }
        logTextView.scrollRangeToVisible(NSRange(location: logTextView.text.count - 1, length: 1))
    }

}
