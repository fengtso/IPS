//
//  CBCentralManagerCtrl.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@protocol CBCentralManagerCtrlDelegate <NSObject>

@required
- (void) updateCMLog:(NSString *)text;
- (void) foundPeripheral:(CBPeripheral *)peripheral :(NSNumber *)RSSI :(NSDictionary *)advertisementData;
- (void) connectedPeripheral:(CBPeripheral *)peripheral;
- (void) disconnectedPeripheral:(CBPeripheral *)peripheral;

@end

@interface CBCentralManagerCtrl : NSObject<CBCentralManagerDelegate>{
}

@property bool CBReady;
@property (nonatomic,strong) CBCentralManager *CBCM;
@property (nonatomic,assign) id<CBCentralManagerCtrlDelegate> delegate;

@end
