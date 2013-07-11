//
//  PacketParser.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/11/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RX_BUFF_LEN  20

@interface PacketParser : NSObject
{
    int byte_counter;
    char rx_buff[RX_BUFF_LEN];
}

- (void) add_bytes:(NSData *) incoming_data;
- (BOOL) is_packet_ready;

@end
