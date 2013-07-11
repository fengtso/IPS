//
//  CBPeripheralCtrl.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@protocol CBPeripheralCtrlDelegate <NSObject>

@required
- (void) updateCPLog:(NSString *)text;
- (void) servicesRead;
- (void) updatedRSSI:(CBPeripheral *)peripheral;
- (void) updatedCharacteristic:(CBPeripheral *)peripheral sUUID:(CBUUID *)sUUID cUUID:(CBUUID *)cUUID data:(NSData *)data;

@end

@interface CBPeripheralCtrl : NSObject <CBPeripheralDelegate>{
}

@property (strong,nonatomic) CBPeripheral *CBP;
@property (strong,nonatomic) id<CBPeripheralCtrlDelegate> delegate;


- (void) writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data;

- (void) readCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID;

- (void) setNotificationForCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID enable:(BOOL)enable;

@end
