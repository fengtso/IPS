//
//  SensorToServerStateMachine.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/11/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBCentralManagerCtrl.h"
#import "PacketParser.h"
#import "PeripheralCell.h"

@protocol SensorToServerStateMachineDelegate <NSObject>
@required
- (void) updateSMLog:(NSString *) text;
- (void) discoveredPeripheral:(NSMutableArray *)discovered_peripherals;
- (void) updateDiscoveredPeripherals:(NSMutableArray *)discovered_peripherals;
@end

@interface SensorToServerStateMachine : NSObject <CBCentralManagerCtrlDelegate, CBPeripheralDelegate, PacketParserDelegate>
{
    NSString *curr_state;
    CBCentralManagerCtrl *CBCMCtrl;
    CBPeripheral *connected_peripheral;
    NSMutableArray *discovered_peripherals;
    
    PacketParser *packet_parser;
    NSDictionary *serviceNames;
    CBCharacteristic *state_machine_characteristics;
    
    NSTimer *timer;
    int num_discovered_peripherals;
    int curr_index_of_pheripheral_to_connect;
}

@property (nonatomic, assign) id<SensorToServerStateMachineDelegate> delegate;
@property (strong,nonatomic) CBCentralManagerCtrl *CBCMCtrl;

- (void) update_state:(NSString *)_curr_state;
- (void) send_inquiry_to_sensor:(NSString *)inquiry_packet_type;
- (void) send_ack_start_packet;
- (void) send_ack_end_packet;
@end
