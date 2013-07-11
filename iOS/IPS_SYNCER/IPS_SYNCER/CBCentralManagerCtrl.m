//
//  CBCentralManagerCtrl.m
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import "CBCentralManagerCtrl.h"

@implementation CBCentralManagerCtrl
@synthesize delegate;
@synthesize CBReady;
@synthesize CBCM;


- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    self.CBReady = false;
    switch (central.state) {
        case CBCentralManagerStatePoweredOff:
            NSLog(@"CoreBluetooth BLE hardware is powered off");
            [self.delegate updateCMLog:@"CoreBluetooth BLE hardware is powered off"];
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
            [self.delegate updateCMLog:@"CoreBluetooth BLE hardware is powered on and ready"];
            self.CBReady = true;
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"CoreBluetooth BLE hardware is resetting");
            [self.delegate updateCMLog:@"CoreBluetooth BLE hardware is resetting"];
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@"CoreBluetooth BLE state is unauthorized");
            [self.delegate updateCMLog:@"CoreBluetooth BLE state is unauthorized"];
            break;
        case CBCentralManagerStateUnknown:
            NSLog(@"CoreBluetooth BLE state is unknown");
            [self.delegate updateCMLog:@"CoreBluetooth BLE state is unknown"];
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
            [self.delegate updateCMLog:@"CoreBluetooth BLE hardware is unsupported on this platform"];
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Did discover peripheral. peripheral: %@ rssi: %@, UUID: %@ advertisementData: %@ ", peripheral, RSSI, peripheral.UUID, advertisementData);
    [self.delegate updateCMLog:[NSString stringWithFormat:@"Did discover peripheral. peripheral: %@ rssi: %@, UUID: %@ advertisementData: %@ ", peripheral, RSSI, peripheral.UUID, advertisementData]];
    [self.delegate foundPeripheral:peripheral :RSSI :advertisementData];
    //Do something when a peripheral is discovered.
}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connection successfull to peripheral: %@ with UUID: %@",peripheral,peripheral.UUID);
    [self.delegate updateCMLog:[NSString stringWithFormat:@"Connection successfull to peripheral: %@ with UUID: %@",peripheral,peripheral.UUID]];
    //Do somenthing after successfull connection.
    [self.delegate connectedPeripheral:peripheral];
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Disconnected from peripheral: %@ with UUID: %@",peripheral,peripheral.UUID);
    [self.delegate updateCMLog:[NSString stringWithFormat:@"Disconnected from peripheral: %@ with UUID: %@",peripheral,peripheral.UUID]];
    //Do something when a peripheral is disconnected.
}
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Connection failed to peripheral: %@ with UUID: %@",peripheral,peripheral.UUID);
    [self.delegate updateCMLog:[NSString stringWithFormat:@"Connection failed to peripheral: %@ with UUID: %@",peripheral,peripheral.UUID]];
    //Do something when a connection to a peripheral failes.
}
- (void) centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
    NSLog(@"Currently connected peripherals :");
    [self.delegate updateCMLog:[NSString stringWithFormat:@"Currently connected peripherals :"]];
    int i = 0;
    for(CBPeripheral *peripheral in peripherals) {
        NSLog(@"[%d] - peripheral : %@ with UUID : %@",i,peripheral,peripheral.UUID);
        [self.delegate updateCMLog:[NSString stringWithFormat:@"[%d] - peripheral : %@ with UUID : %@",i,peripheral,peripheral.UUID]];
        //Do something on each connected peripheral.
    }
    
}

- (void) centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
    NSLog(@"Currently known peripherals :");
    [self.delegate updateCMLog:[NSString stringWithFormat:@"Currently known peripherals :"]];
    int i = 0;
    for(CBPeripheral *peripheral in peripherals) {
        NSLog(@"[%d] - peripheral : %@ with UUID : %@",i,peripheral,peripheral.UUID);
        [self.delegate updateCMLog:[NSString stringWithFormat:@"[%d] - peripheral : %@ with UUID : %@",i,peripheral,peripheral.UUID]];
        //Do something on each known peripheral.
    }
}

@end
