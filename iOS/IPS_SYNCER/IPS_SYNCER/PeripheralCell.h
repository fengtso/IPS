//
//  PeripheralCell.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface PeripheralCell : NSObject

@property (retain) CBPeripheral *peripheral;
@property (nonatomic, copy) NSNumber *rssi;

@end

