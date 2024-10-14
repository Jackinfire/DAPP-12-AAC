//
//  ViewController.swift
//  Mouse_Gyro_bT
//
//  Created by Om Mahajan on 02/06/2024.
//

import UIKit
import CoreMotion
import CoreBluetooth

class ViewController: UIViewController, CBPeripheralManagerDelegate {
    
    let motionManager = CMMotionManager()
    var peripheralManager: CBPeripheralManager?
    var transferCharacteristic: CBMutableCharacteristic?
    
    let serviceUUID = CBUUID(string: "1234")
    let characteristicUUID = CBUUID(string: "5678")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] (motion, error) in
                guard let motion = motion else { return }
                self?.sendMotionData(motion: motion)
            }
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let transferCharacteristic = CBMutableCharacteristic(
                type: characteristicUUID,
                properties: [.notify, .read, .write],
                value: nil,
                permissions: [.readable, .writeable]
            )
            
            let transferService = CBMutableService(type: serviceUUID, primary: true)
            transferService.characteristics = [transferCharacteristic]
            
            peripheralManager?.add(transferService)
            peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
            
            self.transferCharacteristic = transferCharacteristic
        } else {
            print("Bluetooth is not available.")
        }
    }
    
    func sendMotionData(motion: CMDeviceMotion) {
        let userAcceleration = motion.userAcceleration
        let rotationRate = motion.rotationRate
        let attitude = motion.attitude
        let quaternion = attitude.quaternion

        let data: [String: Double] = [
            "accel_x": userAcceleration.x,
            "accel_y": userAcceleration.y,
            "accel_z": userAcceleration.z,
            "gyro_x": rotationRate.x,
            "gyro_y": rotationRate.y,
            "gyro_z": rotationRate.z,
            "attitude_roll": attitude.roll,
            "attitude_pitch": attitude.pitch,
            "attitude_yaw": attitude.yaw,
            "quaternion_x": quaternion.x,
            "quaternion_y": quaternion.y,
            "quaternion_z": quaternion.z,
            "quaternion_w": quaternion.w
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
            if let transferCharacteristic = transferCharacteristic {
                let chunkSize = 20
                let dataLength = jsonData.count
                var offset = 0

                while offset < dataLength {
                    let amountToSend = min(chunkSize, dataLength - offset)
                    let chunk = jsonData.subdata(in: offset..<(offset + amountToSend))
                    peripheralManager?.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)
                    offset += amountToSend
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager.stopDeviceMotionUpdates()
        peripheralManager?.stopAdvertising()
    }
}
