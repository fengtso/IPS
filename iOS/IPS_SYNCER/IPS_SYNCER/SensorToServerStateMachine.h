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
    
    BOOL debug_mode;
    
    int curr_sequence_num;
    int num_retry_nack;
    NSString *transmitting_data_packet_type;
    BOOL isPacketOutOfOrder;
    BOOL isStateMachineOff;
}

@property (nonatomic, assign) id<SensorToServerStateMachineDelegate> delegate;
@property (strong,nonatomic) CBCentralManagerCtrl *CBCMCtrl;

- (void) update_state:(NSString *)_curr_state;
- (void) send_inquiry_to_sensor:(NSString *)inquiry_packet_type;
- (void) send_ack_start_packet;
- (void) send_ack_end_packet;
- (void) send_nack_to_sensor:(NSString *) nack_packet_type :(int)sequence_num;
- (void) send_debug_packet;
- (void) send_data_to_server:(NSString *)packet_type :(NSDictionary *)data_fields;

@end
