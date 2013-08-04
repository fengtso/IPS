//
//  PacketParser.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/11/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RX_BUFF_LEN  20

@protocol PacketParserDelegate <NSObject>
@required
- (void) didReceivePacket:(NSString *)packet_type :(NSDictionary *)data_fields;
- (void) didReceiveData:(NSData *)data;
@end

@interface PacketParser : NSObject
{
    int byte_counter;
    char rx_buff[RX_BUFF_LEN];
    NSString* device_uuid;
    int curr_uptime;
    int curr_uptime_timestamp_since1970;
    BOOL isLastByeEOF;
}

- (void) add_bytes:(NSData *) incoming_data;
- (void) set_device_uuid:(NSString *) uuid;

@property (nonatomic,assign) id<PacketParserDelegate> delegate;

@end
