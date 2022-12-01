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


 protocol RemotePeripheralViewControllerDelegate: AnyObject {
    func remotePeripheralViewControllerWillDismiss(_ remotePeripheralViewController: BLERemotePeripheralViewController)
}

class BLERemotePeripheralViewController: UIViewController, BKRemotePeripheralDelegate, BKRemotePeerDelegate, LoggerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: Properties

    internal weak var delegate: RemotePeripheralViewControllerDelegate?
    internal var central: BKCentral?
    internal var remotePeripheral: BKRemotePeripheral?

    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var receiverImageView: UIImageView!
    @IBOutlet weak var pickImageButton: UIButton!

    private lazy var sendDataBarButtonItem: UIBarButtonItem! = { UIBarButtonItem(title: "Send Data", style: UIBarButtonItem.Style.plain, target: self, action: #selector(BLERemotePeripheralViewController.sendData)) }()

    // MARK: Initialization

    // MARK: UIViewController Life Cycle

    internal override func viewDidLoad() {

        remotePeripheral?.delegate = self
        remotePeripheral?.peripheralDelegate = self

        navigationItem.title = remotePeripheral?.name
        navigationItem.rightBarButtonItem = sendDataBarButtonItem
        Logger.delegate = self

        view.backgroundColor = UIColor.white
        #if os(iOS)
            logTextView.isEditable = false
        #endif
        logTextView.alwaysBounceVertical = true

        Logger.log("Awaiting data from peripheral")

        pickImageButton.addTarget(self, action: #selector(BLERemotePeripheralViewController.pickImage), for: .touchUpInside)
    }

    internal override func viewWillDisappear(_ animated: Bool) {
        delegate?.remotePeripheralViewControllerWillDismiss(self)
    }

    // MARK: Functions

    // MARK: BKRemotePeripheralDelegate

    internal func remotePeripheral(_ remotePeripheral: BKRemotePeripheral, didUpdateName name: String) {
        navigationItem.title = name
        Logger.log("Name change: \(name)")
    }

    internal func remotePeer(_ remotePeer: BKRemotePeer, didSendArbitraryData data: Data) {
     //   Logger.log("Received data of length: \(data.count) with hash: \(data.md5().toHexString())")
        let image = UIImage(data: data)
        print(image)
        receiverImageView.image = image
    }

    internal func remotePeripheralIsReady(_ remotePeripheral: BKRemotePeripheral) {
        Logger.log("Peripheral ready: \(remotePeripheral)")
    }

    // MARK: Target Actions

    @objc private func pickImage() {
        let imagePickerController = UIImagePickerController()
          imagePickerController.allowsEditing = false // If you want edit option set "true"
          imagePickerController.sourceType = .photoLibrary
          imagePickerController.delegate = self
          present(imagePickerController, animated: true, completion: nil)
    }

    @objc private func sendData() {

      //  let numberOfBytesToSend: Int = Int(arc4random_uniform(950) + 50)
        // var data = Data.dataWithNumberOfBytes(numberOfBytesToSend)
        guard let data = receiverImageView.image?.compress(to: 300) else { return }
       // print("Image============= \(data.base64EncodedString())")
       // Logger.log("Prepared \(numberOfBytesToSend) bytes with MD5 hash: \(data.md5().toHexString())")
        Logger.log("Sending to \(remotePeripheral)")
        
        IHProgressHUD.show(withStatus: "Sending data to central")
        central?.sendData(data, toRemotePeer: remotePeripheral!) { _, remotePeripheral, error in
            guard error == nil else {
                IHProgressHUD.showError(withStatus: "Failed sending to \(remotePeripheral)")
                Logger.log("Failed sending to \(remotePeripheral)")
                return
            }
            IHProgressHUD.showSuccesswithStatus("Success")
            Logger.log("Sent to \(remotePeripheral)")
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let tempImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        receiverImageView.image  = tempImage

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
extension UIImage {
    func resized(withPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: size.width * percentage, height: size.height * percentage)
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }

    func compress(to kb: Int, allowedMargin: CGFloat = 0.2) -> Data {
        let bytes = kb * 1024
        var compression: CGFloat = 1.0
        let step: CGFloat = 0.05
        var holderImage = self
        var complete = false
        while !complete {
            if let data = holderImage.jpegData(compressionQuality: 1.0) {
                let ratio = data.count / bytes
                if data.count < Int(CGFloat(bytes) * (1 + allowedMargin)) {
                    complete = true
                    return data
                } else {
                    let multiplier: CGFloat = CGFloat((ratio / 5) + 1)
                    compression -= (step * multiplier)
                }
            }

            guard let newImage = holderImage.resized(withPercentage: compression) else { break }
            holderImage = newImage
        }
        return Data()
    }
}
