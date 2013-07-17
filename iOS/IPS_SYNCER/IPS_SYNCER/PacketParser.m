//
//  PacketParser.m
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/11/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import "PacketParser.h"

@implementation PacketParser

const unsigned char BOF = 0xc0;
const unsigned char EEOF = 0xc1;
const unsigned char loc_packet_type = 0xaa;
const unsigned char imu_packet_type = 0xbb;
const unsigned char start_packet_type = 0xf0;
const unsigned char end_packet_type = 0xf1;

- (void) add_bytes:(NSData *)incoming_data
{
    //NSLog(@"adding incoming bytes:%@", incoming_data);
    [self.delegate didReceiveData:incoming_data];
    
    for (int i = 0; i < [incoming_data length]; i++) {
        char curr_byte;
        
        // Extract one byte
        [incoming_data getBytes:&curr_byte range:NSMakeRange(i, 1)];

        // Find BOF
        if ((curr_byte & 0xff) == BOF) {
            byte_counter = 0;
        }
        
        // Append byte
        rx_buff[byte_counter] = (curr_byte & 0xff);
        byte_counter++;
        
        // Check EOF
        if((curr_byte & 0xff) == EEOF && byte_counter == RX_BUFF_LEN){
            NSData* packetData = [[NSData alloc] initWithBytes:rx_buff length: RX_BUFF_LEN];
            //NSLog(@"valid packet=%@", packetData);
            [self process_packet:packetData];
        }
    }
}

- (void) set_device_uuid:(NSString *) uuid;
{
    device_uuid = uuid;
    NSLog(@"setting device_uuid=%@", device_uuid);
    byte_counter = 0;
}

- (void) process_packet:(NSData *) packetData
{    
    // Get packet type
    unsigned char packet_type;
    [packetData getBytes:&packet_type range:NSMakeRange(1, 1)];

    unsigned char packet_type_to_inquiry;
    [packetData getBytes:&packet_type_to_inquiry range:NSMakeRange(2, 1)];

    int current_uptime = 0;
    NSNumber* current_uptime_nsnumber;
    
    int uptime;
    NSNumber* uptime_nsnumber;
    
    int sequence_number;
    NSNumber* sequence_number_nsnumber;
    
    NSData *uid_record;
    
    NSString* inquiry_packet_type;


    // Decode packet
    NSMutableArray *keys;
    NSMutableArray *objects;
    NSDictionary *dictionary;
    
    switch (packet_type) {
        case start_packet_type:
            // Parse current_uptime
            [packetData getBytes:&current_uptime range:NSMakeRange(3, 4)];
            current_uptime_nsnumber = [NSNumber numberWithInt:current_uptime];
            
            // Update curr_uptime
            curr_uptime = current_uptime;
            curr_uptime_timestamp_since1970 = [[NSDate date] timeIntervalSince1970];
            
            keys = [NSArray arrayWithObjects:@"packet_type", @"packet_type_to_inquiry", @"current_uptime", nil];
            
            if (packet_type_to_inquiry == 0xaa) {
                inquiry_packet_type = @"0xaa";
            }
            objects = [NSArray arrayWithObjects:@"0xf0", inquiry_packet_type, current_uptime_nsnumber, nil];
            
            dictionary = [NSDictionary dictionaryWithObjects:objects
                                                     forKeys:keys];
            [self.delegate didReceivePacket:@"start_packet" :dictionary];

            break;
            
        case end_packet_type:
            // Parse current_uptime
            [packetData getBytes:&current_uptime range:NSMakeRange(3, 4)];
            current_uptime_nsnumber = [NSNumber numberWithInt:current_uptime];
            
            keys = [NSArray arrayWithObjects:@"packet_type", @"packet_type_to_inquiry", @"current_uptime", nil];
            
            if (packet_type_to_inquiry == 0xaa) {
                inquiry_packet_type = @"0xaa";
            }
            objects = [NSArray arrayWithObjects:@"0xf1", inquiry_packet_type, current_uptime_nsnumber, nil];
            
            dictionary = [NSDictionary dictionaryWithObjects:objects
                                                     forKeys:keys];
            [self.delegate didReceivePacket:@"end_packet" :dictionary];
            
            break;

            
        case loc_packet_type:
            // Parse sequence number
            [packetData getBytes:&sequence_number range:NSMakeRange(2, 4)];
            sequence_number_nsnumber = [NSNumber numberWithInt:sequence_number];
            
            // Parse uptime
            [packetData getBytes:&uptime range:NSMakeRange(6, 4)];
            uptime_nsnumber = [NSNumber numberWithInt:uptime];
            
            // Calculate corresponding absolute timestamp
            int abs_timestamp = curr_uptime_timestamp_since1970 + (uptime - curr_uptime);
            
            // Parse uid_record
            uid_record = [packetData subdataWithRange:NSMakeRange(10, 8)];
            
            keys = [NSArray arrayWithObjects:@"packet_type", @"device_uuid", @"sequence_number", @"timestamp", @"uid_record", nil];
     
            objects = [NSArray arrayWithObjects:@"0xaa", device_uuid, sequence_number_nsnumber, [NSNumber numberWithInt:abs_timestamp], uid_record, nil];
            
            dictionary = [NSDictionary dictionaryWithObjects:objects
                                                     forKeys:keys];
            [self.delegate didReceivePacket:@"loc_packet" :dictionary];
            
            break;
            
        case imu_packet_type:

            break;
            
        default:
            break;
    }
    
}

@end
