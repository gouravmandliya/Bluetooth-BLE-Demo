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
import CoreBluetooth

@available(iOS 13.0, *)
class BLECentralViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, BKCentralDelegate, AvailabilityViewController, RemotePeripheralViewControllerDelegate {
  
    // MARK: Properties

    @IBOutlet weak var tableV: UITableView!
    
    internal var availabilityView = AvailabilityView()

    private var activityIndicator: UIActivityIndicatorView? {
        guard let activityIndicator = activityIndicatorBarButtonItem.customView as? UIActivityIndicatorView else {
            return nil
        }
        return activityIndicator
    }

    private let activityIndicatorBarButtonItem = UIBarButtonItem(customView: UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium))
    private var discoveries = [BKDiscovery]()
    private let discoveriesTableViewCellIdentifier = "Discoveries Table View Cell Identifier"
    private let central = BKCentral()

    // MARK: UIViewController Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        activityIndicator?.color = UIColor.black
        navigationItem.title = "Central"
        navigationItem.rightBarButtonItem = activityIndicatorBarButtonItem
        applyAvailabilityView()
        tableV.register(UITableViewCell.self, forCellReuseIdentifier: discoveriesTableViewCellIdentifier)
        tableV.dataSource = self
        tableV.delegate = self
        startCentral()
    }

    override func viewDidAppear(_ animated: Bool) {
        scan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        central.interruptScan()
    }

    deinit {
        _ = try? central.stop()
    }

    // MARK: Functions

    private func startCentral() {
        do {
            central.delegate = self
            central.addAvailabilityObserver(self)
            let dataServiceUUID = UUID(uuidString: "6E6B5C64-FAF7-40AE-9C21-D4933AF45B23")!
            let dataServiceCharacteristicUUID = UUID(uuidString: "477A2967-1FAB-4DC5-920A-DEE5DE685A3D")!
            let configuration = BKConfiguration(dataServiceUUID: dataServiceUUID, dataServiceCharacteristicUUID: dataServiceCharacteristicUUID)
            try central.startWithConfiguration(configuration)
        } catch let error {
            print("Error while starting: \(error)")
        }
    }

    private func scan() {
        central.scanContinuouslyWithChangeHandler({ changes, discoveries in
            
            let indexPathsToRemove = changes.filter({ $0 == .remove(discovery: nil) }).map({ IndexPath(row: self.discoveries.firstIndex(of: $0.discovery) ?? 0, section: 0) })
            self.discoveries = discoveries
            
            let indexPathsToInsert = changes.filter({ $0 == .insert(discovery: nil) }).map({ IndexPath(row: self.discoveries.firstIndex(of: $0.discovery) ?? 0, section: 0) })
            DispatchQueue.main.async {
                if !indexPathsToRemove.isEmpty {
                    self.tableV.deleteRows(at: indexPathsToRemove, with: UITableView.RowAnimation.automatic)
                }
                if !indexPathsToInsert.isEmpty {
                    self.tableV.insertRows(at: indexPathsToInsert, with: UITableView.RowAnimation.automatic)
                }
            }
            
            for insertedDiscovery in changes.filter({ $0 == .insert(discovery: nil) }) {
                Logger.log("Discovery: \(insertedDiscovery)")
            }
        }, stateHandler: { newState in
            if newState == .scanning {
                self.activityIndicator?.startAnimating()
                return
            } else if newState == .stopped {
                self.discoveries.removeAll()
                DispatchQueue.main.async {
                    self.tableV.reloadData()
                }
             
            }
            self.activityIndicator?.stopAnimating()
        }, errorHandler: { error in
            Logger.log("Error from scanning: \(error)")
        })
    }

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveries.count
    }
    

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableV.dequeueReusableCell(withIdentifier: discoveriesTableViewCellIdentifier, for: indexPath)
        let discovery = discoveries[indexPath.row]
        cell.textLabel?.text = discovery.localName != nil ? discovery.localName : discovery.remotePeripheral.name
        return cell
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableV.isUserInteractionEnabled = false
        central.connect(remotePeripheral: discoveries[indexPath.row].remotePeripheral) { remotePeripheral, error in
            self.tableV.isUserInteractionEnabled = true
            guard error == nil else {
                print("Error connecting peripheral: \(String(describing: error))")
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let remotePeripheralViewController = storyboard.instantiateViewController(withIdentifier: "BLERemotePeripheralViewController") as? BLERemotePeripheralViewController

            remotePeripheralViewController!.central = self.central
            remotePeripheralViewController!.remotePeripheral = remotePeripheral
            remotePeripheralViewController!.delegate = self
            self.navigationController?.pushViewController(remotePeripheralViewController!, animated: true)
        }
    }

    // MARK: BKAvailabilityObserver

    internal func availabilityObserver(_ availabilityObservable: BKAvailabilityObservable, availabilityDidChange availability: BKAvailability) {
        availabilityView.availabilityObserver(availabilityObservable, availabilityDidChange: availability)
        if availability == .available {
            scan()
        } else {
            central.interruptScan()
        }
    }
    
    func applyAvailabilityView() {
        
    }

    // MARK: BKCentralDelegate

    internal func central(_ central: BKCentral, remotePeripheralDidDisconnect remotePeripheral: BKRemotePeripheral) {
        Logger.log("Remote peripheral did disconnect: \(remotePeripheral)")
        _ = self.navigationController?.popToViewController(self, animated: true)
    }

    // MARK: RemotePeripheralViewControllerDelegate

     func remotePeripheralViewControllerWillDismiss(_ remotePeripheralViewController: BLERemotePeripheralViewController) {
        do {
            try central.disconnectRemotePeripheral(remotePeripheralViewController.remotePeripheral!)
        } catch let error {
            Logger.log("Error disconnecting remote peripheral: \(error)")
        }
    }
}
