//
//  SensorToServerStateMachine.m
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/11/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import "SensorToServerStateMachine.h"

#define IPS_DATA_SERVICE @"0bd51666-e7cb-469b-8e4d-2742f1ba77cc"
#define IPS_DATA_CHARACTERISTIC @"e7add780-b042-4876-aae1-112855353cc1"
#define rest_interval 1
#define scan_interval 5


@implementation SensorToServerStateMachine

@synthesize CBCMCtrl;

-(id)init
{
    self = [super init]; // Here you call the superclass init
    if(self) {
        curr_state = @"rest";
        
        CBCMCtrl = [CBCentralManagerCtrl alloc];
        if (CBCMCtrl) {
            CBCMCtrl.CBCM = [[CBCentralManager alloc] initWithDelegate:CBCMCtrl queue:nil];
            CBCMCtrl.delegate = self;
        }
        
        packet_parser = [[PacketParser alloc] init];
        packet_parser.delegate = self;
        
        connected_peripheral = nil;
        discovered_peripherals = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

- (void) send_data_to_server:(NSDictionary *)data_fields
{
}

- (void) send_inquiry_to_sensor:(NSString *)inquiry_packet_type
{
    if ([inquiry_packet_type isEqualToString:@"loc_data"]) {
        NSData* data_to_send = [self create_packet:1 :0];
        [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
    }
}

- (void) send_ack_to_sensor:(NSString *)ack_packet_type
{
}

- (void) send_nack_to_sensor:(NSString *) nack_packet_type :(NSNumber *)sequence_num
{
}

- (void) stop_rest
{
    [timer invalidate];
    timer = nil;
    
    [self update_state:@"stop_rest"];
}

- (void) start_scan
{
    [discovered_peripherals removeAllObjects];
    
    if (CBCMCtrl.CBReady) {
        [CBCMCtrl.CBCM stopScan];
        // BLE HW is ready start scanning for peripherals now.
        NSArray * services=[NSArray arrayWithObjects:
                            [CBUUID UUIDWithString:IPS_DATA_SERVICE],
                            nil
                            ];
        [CBCMCtrl.CBCM scanForPeripheralsWithServices:services options:nil];
    }
}

- (void) stop_scan
{
    // Get number of discovered peripherals
    num_discovered_peripherals = [discovered_peripherals count];
    curr_index_of_pheripheral_to_connect = 0;
    
    [self.delegate updateSMLog:[NSString stringWithFormat:@"%d sensors are found", num_discovered_peripherals]];
    for (int i = 0; i < num_discovered_peripherals; i++) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"UUID:%@", ((PeripheralCell*)discovered_peripherals[i]).peripheral.UUID]];
    }
    
    [self update_state:@"stop_scan"];
}

- (void) connect
{
    PeripheralCell* per=[discovered_peripherals objectAtIndex:curr_index_of_pheripheral_to_connect];
    [self.delegate updateSMLog:@"Connecting ..."];
    [self.delegate updateSMLog:[NSString stringWithFormat:@"UUID:%@", per.peripheral.UUID]];
    [self.CBCMCtrl.CBCM connectPeripheral:per.peripheral options:nil];
}

- (void) diconnect
{
    if(connected_peripheral){
        [self.CBCMCtrl.CBCM cancelPeripheralConnection:connected_peripheral];
        connected_peripheral = nil;
    }
}

- (void) send_inquiry_packet
{
    // loc_packet_type
    NSData* data_to_send = [self create_packet:1 :0];
    [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
}

/*
 *  Implement a finite state machine
 *
 *  @param curr_state current state
 */

- (void) update_state:(NSString *)_curr_state
{    
    if ([_curr_state isEqualToString:@"start_rest"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        
        timer = [NSTimer scheduledTimerWithTimeInterval:rest_interval
                                                        target:self
                                               selector:@selector(stop_rest)
                                                      userInfo:nil
                                                       repeats:NO];
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"stop_rest"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        
        [self update_state:@"start_scan"];
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"start_scan"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        
        [self start_scan];
        timer = [NSTimer scheduledTimerWithTimeInterval:scan_interval
                                                 target:self
                                               selector:@selector(stop_scan)
                                               userInfo:nil
                                                repeats:NO];
        return;
    }
    
    
    if ([_curr_state isEqualToString:@"stop_scan"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        [self update_state:@"connect"];
        return;
    }
    
    if ([_curr_state isEqualToString:@"connect"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        
        if (num_discovered_peripherals < 1 || curr_index_of_pheripheral_to_connect == num_discovered_peripherals) {
            [self update_state:@"start_rest"];
        }
        else{
            [self connect];
        }
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"connected"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        curr_index_of_pheripheral_to_connect++;
        
        return;
    }
    
    
    if ([_curr_state isEqualToString:@"inquiry"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        [self send_inquiry_packet];
        return;
    }
    
    if ([_curr_state isEqualToString:@"disconnect"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        return;
    }
    
    if ([_curr_state isEqualToString:@"disconnected"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]==========", _curr_state]];
        return;
    }
    
}

-(void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data {
    // Sends data to BLE peripheral to process HID and send EHIF command to PC
    [self.delegate updateSMLog:[NSString stringWithFormat:@"Sending %@ to peripheral",data]];
    for ( CBService *service in peripheral.services ) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"Service %@",service.UUID]];
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for ( CBCharacteristic *characteristic in service.characteristics ) {
                [self.delegate updateSMLog:[NSString stringWithFormat:@"Characteristic %@",characteristic.UUID]];
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    /* EVERYTHING IS FOUND, WRITE characteristic ! */
                    [self.delegate updateSMLog:@"Found Service, Characteristic, writing value"];
                    [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];                    
                }
            }
        }
    }
}

/*  @param packet_type 1:inquiry_loc_packet 2:inquiry_imu_packet 3:ack 4:nack
 *  @param seq_num  sequence number for ack or nack
 */
- (NSData*) create_packet:(int)packet_type :(NSString*)seq_num
{
    NSMutableData *packet = [[NSMutableData alloc] initWithCapacity:20];
    unsigned char BOF[] = {0xC0};
    unsigned char EEOF[] = {0xC1};
    unsigned char inquiry_packet_type[] = {0xCC};
    unsigned char ack_packet_type[] = {0xDD};
    unsigned char nack_packet_type[] = {0xEE};
    unsigned char loc_packet_type[] = {0xAA};
    unsigned char imu_packet_type[] = {0xBB};
    unsigned char dummy_bytes[] = {0x00};
    int seq_num_intvalue = 0;
    
    // Append BOF
    [packet appendBytes:BOF length:1];
    
    switch(packet_type){
        case 1:
            // Append packet type
            [packet appendBytes:inquiry_packet_type length:1];
            
            // Append inquiry packet type
            [packet appendBytes:loc_packet_type length:1];
            
            // Append dummy field
            for (int i = 0; i < 16; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 2:
            // Append packet type
            [packet appendBytes:inquiry_packet_type length:1];
            
            // Append inquiry packet type
            [packet appendBytes:imu_packet_type length:1];
            
            // Append dummy field
            for (int i = 0; i < 16; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 3:
            // Append packet type
            [packet appendBytes:ack_packet_type length:1];
            
            // Append inquiry packet type
            [packet appendBytes:loc_packet_type length:1];
            
            // Append sequence number
            seq_num_intvalue = [seq_num intValue];
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            
            // Append dummy field
            for (int i = 0; i < 12; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 4:
            // Append packet type
            [packet appendBytes:nack_packet_type length:1];
            
            // Append inquiry packet type
            [packet appendBytes:loc_packet_type length:1];
            
            // Append sequence number
            seq_num_intvalue = [seq_num intValue];
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            
            // Append dummy field
            for (int i = 0; i < 12; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
        default:
            break;
    }
    
    // Append EOF
    [packet appendBytes:EEOF length:1];
    
    return packet;
}


/*  PacketParser delegate function
 *  Delegate function for PacketParser
 *  @param packet_type "start_packet", "end_packet", "loc_packet", "imu_packet"
 */
- (void) didReceivePacket:(NSString *)packet_type :(NSDictionary *)data_fields
{
    NSLog(@"received a %@, parsed_data_dict=%@", packet_type, data_fields);
    
}

- (void) discover_services{
    NSArray *keys = [NSArray arrayWithObjects:
                     [CBUUID UUIDWithString:IPS_DATA_SERVICE],
                     nil];
    NSArray *objects = [NSArray arrayWithObjects:
                        @"IPS Data Service",
                        nil];
    
    serviceNames = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    
    [connected_peripheral discoverServices:[serviceNames allKeys]];
}

// CBCentralManagerCtrl delegate functions
- (void) updateCMLog:(NSString *)text
{
    //[self.delegate updateSMLog:text];
}

- (void) foundPeripheral:(CBPeripheral *)peripheral :(NSNumber *)RSSI :(NSDictionary *)advertisementData
{
    
    BOOL (^test)(id obj, NSUInteger idx, BOOL *stop);
    test = ^ (id obj, NSUInteger idx, BOOL *stop) {
        NSString *new_peripheral_uuid = [[NSString alloc] initWithFormat:@"%@", peripheral.UUID];
        NSString *obj_peripheral_uuid = [[NSString alloc] initWithFormat:@"%@", [obj peripheral].UUID];
        /*
        if([[[obj peripheral] name] compare:peripheral.name] == NSOrderedSame)
            return YES;
        return NO;
        */
        if ([new_peripheral_uuid isEqualToString:obj_peripheral_uuid]) {
            return YES;
        }
    
        return NO;
      
    };
    
    PeripheralCell* cell;
    NSUInteger t=[discovered_peripherals indexOfObjectPassingTest:test];
    if(t!= NSNotFound)
    {
        cell=[discovered_peripherals objectAtIndex:t];
        cell.peripheral=peripheral;
        cell.rssi=RSSI;
    }else{
        cell=[[PeripheralCell alloc] init];
        [discovered_peripherals addObject: cell];
        cell.peripheral=peripheral;
        cell.rssi=RSSI;
    }
    
    // Let UIViewController to show peripherals
    [self.delegate discoveredPeripheral:discovered_peripherals];

}

- (void) connectedPeripheral:(CBPeripheral *)peripheral
{
    [self.delegate updateSMLog:@"Connected ..."];
    [self.delegate updateSMLog:[NSString stringWithFormat:@"UUID:%@",peripheral.UUID]];
    
    connected_peripheral = peripheral;
    [connected_peripheral setDelegate:self];
    
    NSString *device_uuid = [[NSString alloc] initWithFormat:@"%@", connected_peripheral.UUID];
    [packet_parser set_device_uuid: device_uuid];
    [self discover_services];
    
    [self update_state:@"connected"];
}

- (void) disconnectedPeripheral:(CBPeripheral *)peripheral
{
    [self.delegate updateSMLog:@"lost connection"];
}



// CBPeripheralDelegate delegate functions
- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if(error != nil)
    {
        //TODO: handle error
        return;
    }
    
    NSEnumerator *e = [service.characteristics objectEnumerator];
    
    if ( (state_machine_characteristics = [e nextObject]) ) {
        [peripheral setNotifyValue:YES forCharacteristic: state_machine_characteristics];
        
        [self update_state:@"inquiry"];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if(error != nil)
    {
        //TODO: handle error
        return;
    }
    
    NSEnumerator *e = [connected_peripheral.services objectEnumerator];
    CBService * service;
    
    while ( (service = [e nextObject]) ) {
        [connected_peripheral discoverCharacteristics:[NSArray arrayWithObject:[CBUUID UUIDWithString:IPS_DATA_SERVICE ]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error != nil)
        return;
    
    NSLog(@"%@", characteristic.value);
    [packet_parser add_bytes:characteristic.value];
}


@end