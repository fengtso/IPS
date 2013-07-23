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

NSString *server_url = @"http://cmu-sensor-network.herokuapp.com/sensors";

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
        
        curr_sequence_num = 0;
        num_retry_nack = 0;
        transmitting_data_packet_type = @"0xaa";
        isPacketOutOfOrder = FALSE;
        isStateMachineOff = FALSE;
        
        debug_mode = FALSE;
    }
    return self;
}

- (NSNumber *) convertNSDataToInteger:(NSData *)data
{
    unsigned long long int d;
    assert([data length] == sizeof(d));
    memcpy(&d, [data bytes], sizeof(d));
    
    return [[NSNumber alloc] initWithUnsignedLongLong:d];
}

- (void) send_data_to_server:(NSString *)packet_type :(NSDictionary *)data_fields
{
    
    NSArray *keys;
    NSArray *objects;
    
    // Create loc_packet information to upload 
    if ([packet_type isEqualToString:@"loc_packet"]) {
        keys = [NSArray arrayWithObjects:@"id", @"timestamp", @"ips_beacon_id", nil];        
        // TODO: location_beacon_id should convert from 8-byte byte array to double?
        NSNumber *ips_beacon_id = [self convertNSDataToInteger:[data_fields objectForKey:@"uid_record" ]];
        //NSNumber *ips_beacon_id = [[NSNumber alloc] initWithDouble:123.456];

        objects = [NSArray arrayWithObjects: [data_fields objectForKey:@"device_uuid"], [data_fields objectForKey:@"timestamp"], ips_beacon_id, nil];
    }
    
    // Create imu_packet information to upload
    if ([packet_type isEqualToString:@"imu_packet"]) {
        
        NSString *record_type_string = @"none";
        if ([[data_fields objectForKey:@"record_type"] intValue] == 0) {
            record_type_string = @"ax";
        }

        if ([[data_fields objectForKey:@"record_type"] intValue] == 1) {
            record_type_string = @"ay";
        }
        
        if ([[data_fields objectForKey:@"record_type"] intValue] == 2) {
            record_type_string = @"az";
        }
        
        // TODO: record_type should include pitch, roll, yaw
    
        keys = [NSArray arrayWithObjects:@"id", @"timestamp",record_type_string, nil];
        
        
        //NSNumber *ips_beacon_id = [[NSNumber alloc] initWithDouble:123.456];
        
        objects = [NSArray arrayWithObjects: [data_fields objectForKey:@"device_uuid"], [data_fields objectForKey:@"timestamp"], [data_fields objectForKey:@"sensor_record"],nil];

    }
    
    NSDictionary *myDataDictionary = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    NSError* err = nil;
    NSData* myJSONData = [NSJSONSerialization dataWithJSONObject:myDataDictionary
                                                         options:NSJSONWritingPrettyPrinted error:&err];
    NSLog(@"%@",[[NSString alloc]initWithData:myJSONData encoding:NSUTF8StringEncoding]);

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSURL *myURL = [NSURL URLWithString:server_url];
    [request setURL:myURL];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:myJSONData];
    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
    
    err = nil;
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *returnData, NSError *error0) {
                               if (!error0) {
                                   NSString *returnData_nsstring = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
                                   NSLog(@"response_data:%@", returnData_nsstring);
                               } else {
                                
                                   NSLog(@"err: %@", error0.localizedDescription);
                               }
                           }];

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

- (void) send_nack_to_sensor:(NSString *) nack_packet_type :(int)sequence_num
{
    if ([nack_packet_type isEqualToString:@"0xaa"]) {
        NSData* data_to_send = [self create_packet:5 :sequence_num];
        [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
        num_retry_nack++;
    }

    if ([nack_packet_type isEqualToString:@"0xbb"]) {
        NSData* data_to_send = [self create_packet:6 :sequence_num];
        [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
        num_retry_nack++;
    }
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
    
    // List found sensors' UUIDs
    [self.delegate updateSMLog:[NSString stringWithFormat:@"%d sensors are found", num_discovered_peripherals]];
    for (int i = 0; i < num_discovered_peripherals; i++) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"UUID:%@", ((PeripheralCell*)discovered_peripherals[i]).peripheral.UUID]];
    }
    
    [self update_state:@"stop_scan"];
}

- (void) connect
{
    PeripheralCell* per=[discovered_peripherals objectAtIndex:curr_index_of_pheripheral_to_connect];
    [self.delegate updateSMLog:@"connecting ..."];
    [self.delegate updateSMLog:[NSString stringWithFormat:@"UUID:%@", per.peripheral.UUID]];
    [self.CBCMCtrl.CBCM connectPeripheral:per.peripheral options:nil];
}

- (void) disconnect
{
    if(connected_peripheral){
        [self.CBCMCtrl.CBCM cancelPeripheralConnection:connected_peripheral];
        connected_peripheral = nil;
    }
}

- (void) debug_connect
{
    debug_mode = TRUE;
}

- (void) send_debug_packet
{
    NSData* data_to_send = [self create_packet:0 :0];
    [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
}

- (void) send_inquiry_packet
{
    if ([transmitting_data_packet_type isEqualToString:@"0xaa"]) {
        // loc_packet_type
        NSData* data_to_send = [self create_packet:1 :0];
        [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
    }
    
    if ([transmitting_data_packet_type isEqualToString:@"0xbb"]) {
        // loc_packet_type
        NSData* data_to_send = [self create_packet:2 :0];
        [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
    }
    
}

- (void) send_ack_start_packet
{
    NSData* data_to_send = [self create_packet:3 :0];
    [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
}

- (void) send_ack_end_packet
{
    NSData* data_to_send = [self create_packet:4 :0];
    [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
    
    
    if ([transmitting_data_packet_type isEqualToString:@"0xaa"]) {
        transmitting_data_packet_type = @"0xbb";
    }
    else if ([transmitting_data_packet_type isEqualToString:@"0xbb"]) {
        // 0xa0 means we finish all data packet type transmission
        transmitting_data_packet_type = @"0xa0";
    }
    
    // Reset params
    [self reset_params];
}

- (void) reset_params
{
    curr_sequence_num = 0;
    num_retry_nack = 0;
    isPacketOutOfOrder = FALSE;
}

- (void) stop_state_machine
{
    [timer invalidate];
    timer = nil;
    
    [self disconnect];
    curr_index_of_pheripheral_to_connect = 0;
    [discovered_peripherals removeAllObjects];
    [self.delegate updateDiscoveredPeripherals:discovered_peripherals];
}

/*
 *  Implement a finite state machine
 *
 *  @param curr_state current state
 */

- (void) update_state:(NSString *)_curr_state
{
    //NSLog(@"update_state: %@", _curr_state);
    
    if ([_curr_state isEqualToString:@"start_debug_mode"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self.delegate updateSMLog:@"+++++++++++++++++++++++++++++\n"];
        debug_mode = TRUE;
        [self update_state:@"start_rest"];
    }
    
    if ([_curr_state isEqualToString:@"start_state_machine"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self.delegate updateSMLog:@"+++++++++++++++++++++++++++++\n"];
        
        isStateMachineOff = FALSE;
        [self update_state:@"start_rest"];
    }
    
    if ([_curr_state isEqualToString:@"stop_state_machine"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self.delegate updateSMLog:@"+++++++++++++++++++++++++++++\n"];

        isStateMachineOff = YES;
        [self stop_state_machine];
    }
    
    if ([_curr_state isEqualToString:@"start_rest"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        
        timer = [NSTimer scheduledTimerWithTimeInterval:rest_interval
                                                        target:self
                                               selector:@selector(stop_rest)
                                                      userInfo:nil
                                                       repeats:NO];
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"stop_rest"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        
        [self update_state:@"start_scan"];
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"start_scan"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        
        [self start_scan];
        timer = [NSTimer scheduledTimerWithTimeInterval:scan_interval
                                                 target:self
                                               selector:@selector(stop_scan)
                                               userInfo:nil
                                                repeats:NO];
        return;
    }
    
    
    if ([_curr_state isEqualToString:@"stop_scan"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self update_state:@"connect"];
        return;
    }
    
    if ([_curr_state isEqualToString:@"connect"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];

        if (num_discovered_peripherals < 1 || curr_index_of_pheripheral_to_connect == num_discovered_peripherals) {
            curr_index_of_pheripheral_to_connect = 0;
            num_discovered_peripherals = 0;
            [self update_state:@"start_rest"];
        }
        else{
            [self connect];
        }
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"connected"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        curr_index_of_pheripheral_to_connect++;
        
        return;
    }
    
    
    if ([_curr_state isEqualToString:@"inquiry"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self send_inquiry_packet];
        return;
    }
    
    if ([_curr_state isEqualToString:@"ack_start_packet"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self send_ack_start_packet];
        return;
    }
    
    if ([_curr_state isEqualToString:@"ack_end_packet"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        
        if (isPacketOutOfOrder) {
            [self update_state:@"nack_packet"];
        }
        else{
            [self send_ack_end_packet];
            // Done with loc_packet, start imu_packet transmission
            if ([transmitting_data_packet_type isEqualToString:@"0xa0"]) {
                NSLog(@"DISCONNECT");

                [self update_state:@"disconnect"];
            }
            else{
                NSLog(@"INQUIRE FOR 0xbb");
                [self update_state:@"inquiry"];
            }
        }
        
        return;
    }
    
    if ([_curr_state isEqualToString:@"nack_packet"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        [self send_nack_to_sensor:transmitting_data_packet_type :curr_sequence_num];
        curr_sequence_num = 0;
        return;
    }
    
    if ([_curr_state isEqualToString:@"disconnect"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];
        
        [self disconnect];
        return;
    }
    
    if ([_curr_state isEqualToString:@"disconnected"]) {
        [self.delegate updateSMLog:[NSString stringWithFormat:@"[%@]", _curr_state]];

        return;
    }
    
}

-(void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data {
    // Sends data to BLE peripheral to process HID and send EHIF command to PC
    [self.delegate updateSMLog:[NSString stringWithFormat:@"Sending %@ to peripheral",data]];
    for ( CBService *service in peripheral.services ) {
        //[self.delegate updateSMLog:[NSString stringWithFormat:@"Service %@",service.UUID]];
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for ( CBCharacteristic *characteristic in service.characteristics ) {
                //[self.delegate updateSMLog:[NSString stringWithFormat:@"Characteristic %@",characteristic.UUID]];
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    /* EVERYTHING IS FOUND, WRITE characteristic ! */
                    //[self.delegate updateSMLog:@"Found Service, Characteristic, writing value"];
                    [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                }
            }
        }
    }
}

/*  @param packet_type 0:debug_packet 1:inquiry_loc_packet 2:inquiry_imu_packet 3:ack_start 4:ack_end 5:nack loc 6:nack imu
 *  @param seq_num  sequence number for ack or nack
 */
- (NSData*) create_packet:(int)packet_type :(int)seq_num
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
    unsigned char start_packet_type[] = {0xF0};
    unsigned char end_packet_type[] = {0xF1};
    unsigned char debug_packet_type[] = {0x55};
    
    int seq_num_intvalue = 0;
    
    // Append BOF
    [packet appendBytes:BOF length:1];
    
    switch(packet_type){
        case 0:
            // Append dummy field
            for (int i = 0; i < 18; i++) {
                [packet appendBytes:debug_packet_type length:1];
            }
            break;
            
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
            
            // Append start packet type
            [packet appendBytes:start_packet_type length:1];
            
            // Append sequence number
            seq_num_intvalue = seq_num;
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            
            // Append dummy field
            for (int i = 0; i < 12; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 4:
            // Append packet type
            [packet appendBytes:ack_packet_type length:1];
            
            // Append end packet type
            [packet appendBytes:end_packet_type length:1];
            
            // Append sequence number
            seq_num_intvalue = seq_num;
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            
            // Append dummy field
            for (int i = 0; i < 12; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 5:
            // Append packet type
            [packet appendBytes:nack_packet_type length:1];
            
            // Append inquiry packet type
            [packet appendBytes:loc_packet_type length:1];
            
            // Append sequence number
            seq_num_intvalue = seq_num;
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            
            // Append dummy field
            for (int i = 0; i < 12; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 6:
            // Append packet type
            [packet appendBytes:nack_packet_type length:1];
            
            // Append inquiry packet type
            [packet appendBytes:imu_packet_type length:1];
            
            // Append sequence number
            seq_num_intvalue = seq_num;
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
    [self.delegate updateSMLog:[NSString stringWithFormat:@"received %@", data_fields]];
    
    if ([packet_type isEqualToString:@"start_packet"]) {

        [self update_state:@"ack_start_packet"];
    }
    
    if ([packet_type isEqualToString:@"end_packet"]) {
    
        [self update_state:@"ack_end_packet"];

    }
    
    if ([packet_type isEqualToString:@"loc_packet"] || [packet_type isEqualToString:@"imu_packet"]) {
        //NSLog(@"data_fields:%@", data_fields);
        
        if (num_retry_nack > 3) {
            [self update_state:@"disconnect"];
        }
        
        // Update transmitting packet type
        transmitting_data_packet_type = [data_fields objectForKey:@"packet_type"];
        
        
        // TODO: remove comment
        NSLog(@"seq %d, %d", [[data_fields objectForKey:@"sequence_number"] intValue], curr_sequence_num);
         if ([[data_fields objectForKey:@"sequence_number"] intValue] == curr_sequence_num ) {
            [self send_data_to_server:packet_type :data_fields];
             
            curr_sequence_num++;
        }
        else{
            isPacketOutOfOrder = TRUE;
            
            NSLog(@"OUT OF ORDER");
        }
        
    }
}

- (void) didReceiveData:(NSData *)data
{
    [self.delegate updateSMLog:[NSString stringWithFormat:@"received bytes %@", data]];
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
    connected_peripheral = peripheral;
    [connected_peripheral setDelegate:self];
    
    NSString *device_uuid = [[NSString alloc] initWithFormat:@"%@", connected_peripheral.UUID];
    device_uuid = [device_uuid substringWithRange:NSMakeRange(([device_uuid length] - 36), 36)];
    
    [packet_parser set_device_uuid: device_uuid];
    [self discover_services];
    
    [self update_state:@"connected"];
}

- (void) disconnectedPeripheral:(CBPeripheral *)peripheral
{
    transmitting_data_packet_type = @"0xaa";
    [self reset_params];


    [self.delegate updateSMLog:@"disconnected"];
    [self.delegate updateSMLog:@"+++++++++++++++++++++++++++++\n"];

    if (!isStateMachineOff) {
        [self update_state:@"connect"];
    }
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
        
        if (!debug_mode) {
            [self update_state:@"inquiry"];
        }
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
    
    //NSLog(@"%@", characteristic.value);
    [packet_parser add_bytes:characteristic.value];
}


@end
