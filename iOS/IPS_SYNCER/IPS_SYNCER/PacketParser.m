//
//  PacketParser.m
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/11/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import "PacketParser.h"

@implementation PacketParser

- (void) add_bytes:(NSData *)incoming_data
{
    NSLog(@"adding bytes:%@", incoming_data);
    
    for (int i = 0; i < [incoming_data length]; i++) {
        Byte curr_byte;
        
        // Extract one byte
        [incoming_data getBytes:&curr_byte range:NSMakeRange(i, 1)];

        // Read Byte 
    }
    
}

- (BOOL) is_packet_ready
{
    return FALSE;
}

@end
