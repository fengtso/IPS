//
//  HomeViewController.m
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import "HomeViewController.h"
#import "PeripheralCell.h"

#define IPS_DATA_SERVICE @"0bd51666-e7cb-469b-8e4d-2742f1ba77cc"
#define IPS_DATA_CHARACTERISTIC @"e7add780-b042-4876-aae1-112855353cc1"

@interface HomeViewController ()

@end

@implementation HomeViewController

@synthesize dbgTextView, scannedResultTable;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    peripherals = [NSMutableArray arrayWithCapacity:1];
    connected_peripheral = nil;
    
    NSLog(@"Initializing BLE");
    [dbgTextView setText:[NSString stringWithFormat:@"%@Initializing BLE\r\n",dbgTextView.text]];
    self.CBCMCtrl = [CBCentralManagerCtrl alloc];
    self.CBPCtrl = [CBPeripheralCtrl alloc];
    if (self.CBCMCtrl) {
        self.CBCMCtrl.CBCM = [[CBCentralManager alloc] initWithDelegate:self.CBCMCtrl queue:nil];
        self.CBCMCtrl.delegate = self;
    }
    
}

/*  @param packet_type 1:inquiry_loc_packet 2:inquiry_imu_packet 3:ack 4:nack
 *  @param seq_num  sequence number for ack or nack
 */
- (NSData*) create_packet:(int)packet_type :(NSString*)seq_num
{
    NSMutableData *packet = [[NSMutableData alloc] initWithCapacity:20];
    unsigned char inquiry_packet_type[] = {0xCC};
    unsigned char ack_packet_type[] = {0xDD};
    unsigned char nack_packet_type[] = {0xEE};
    unsigned char loc_packet_type[] = {0xAA};
    unsigned char imu_packet_type[] = {0xBB};
    unsigned char dummy_bytes[] = {0x00};
    int seq_num_intvalue = 0;
    
    switch(packet_type){
        case 1:
            [packet appendBytes:inquiry_packet_type length:1];
            [packet appendBytes:loc_packet_type length:1];
            
            for (int i = 0; i < 18; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
        
        case 2:
            [packet appendBytes:inquiry_packet_type length:1];
            [packet appendBytes:imu_packet_type length:1];
            
            for (int i = 0; i < 18; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 3:
            [packet appendBytes:ack_packet_type length:1];
            seq_num_intvalue = [seq_num intValue];
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            for (int i = 0; i < 15; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
            
        case 4:
            [packet appendBytes:nack_packet_type length:1];
             seq_num_intvalue = [seq_num intValue];
            [packet appendBytes:&seq_num_intvalue length:sizeof(int)];
            for (int i = 0; i < 15; i++) {
                [packet appendBytes:dummy_bytes length:1];
            }
            break;
        default:
            break;
    }

    return packet;
}

- (IBAction)scanButtonPressed:(id)sender {
    [self start_scan_peripheral];
}

- (IBAction)sendButtonPressed:(id)sender {
    
    UIButton* btn = (UIButton*)sender;
    NSData* data_to_send = [self create_packet:btn.tag :self.seqNumTextField.text];
    [self writeCharacteristic:connected_peripheral sUUID:IPS_DATA_SERVICE cUUID:IPS_DATA_CHARACTERISTIC data:data_to_send];
}

- (IBAction)logBtnPressed:(id)sender
{
    dbgTextView.hidden = !dbgTextView.hidden;
}

- (IBAction)clearBtnPressed:(id)sender
{
    dbgTextView.text = @"";
}

-(void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data {
    // Sends data to BLE peripheral to process HID and send EHIF command to PC
    NSLog(@"Sending %@ to peripheral",data);
    [self updateLog:[NSString stringWithFormat:@"Sending %@ to peripheral",data]];
    for ( CBService *service in peripheral.services ) {
        NSLog(@"Service %@",service.UUID);
        [self updateLog:[NSString stringWithFormat:@"Service %@",service.UUID]];
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for ( CBCharacteristic *characteristic in service.characteristics ) {
                NSLog(@"Characteristic %@",characteristic.UUID);
                [self updateLog:[NSString stringWithFormat:@"Characteristic %@",characteristic.UUID]];
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    /* EVERYTHING IS FOUND, WRITE characteristic ! */
                    NSLog(@"Found Service, Characteristic, writing value");
                    [self updateLog:@"Found Service, Characteristic, writing value"];
                    [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                    
                }
            }
        }
    }
}

- (void) start_scan_peripheral
{
    if (self.CBCMCtrl.CBReady) {
        [self.CBCMCtrl.CBCM stopScan];
        // BLE HW is ready start scanning for peripherals now.
        NSLog(@"Button pressed, start scanning ...");
        //[self.scanButton setTitle:@"Scanning ..." forState:UIControlStateNormal];
        [peripherals removeAllObjects];
        [scannedResultTable reloadData];
        
        NSArray * services=[NSArray arrayWithObjects:
                            [CBUUID UUIDWithString:IPS_DATA_SERVICE],
                            nil
                            ];
        [self.CBCMCtrl.CBCM scanForPeripheralsWithServices:services options:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"foundDevice";
    
    UITableViewCell *cell = [scannedResultTable dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell.
    PeripheralCell*pcell=[peripherals objectAtIndex: [indexPath row]];
    cell.textLabel.text = [pcell.peripheral name];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"RSSI %d",[pcell.rssi intValue]];

    //self.colorNames objectAtIndex: [indexPath row]];
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(peripherals==nil)
        return 0;
    return [peripherals count];
}

/*
 user selected row
 stop scanner
 connect peripheral for service search
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (connected_peripheral) {
        [self.CBCMCtrl.CBCM cancelPeripheralConnection:connected_peripheral];
        connected_peripheral = nil;
    }
    else{
        PeripheralCell* per=[peripherals objectAtIndex:[indexPath row]];
        [self.CBCMCtrl.CBCM connectPeripheral:per.peripheral options:nil];
    }
}

- (void) updateCMLog:(NSString *)text {
    [dbgTextView setText:[NSString stringWithFormat:@"%@%@\r\n",dbgTextView.text,text]];
}

- (void) updateCPLog:(NSString *)text {
    [dbgTextView setText:[NSString stringWithFormat:@"%@%@\r\n",dbgTextView.text,text]];
}

- (void) updateLog:(NSString *)text{
    [dbgTextView setText:[NSString stringWithFormat:@"%@%@\r\n",dbgTextView.text,text]];
}

- (void) servicesRead{

}

- (void) foundPeripheral:(CBPeripheral *)peripheral :(NSNumber *)RSSI :(NSDictionary *)advertisementData{
    
    BOOL (^test)(id obj, NSUInteger idx, BOOL *stop);
    test = ^ (id obj, NSUInteger idx, BOOL *stop) {
        if([[[obj peripheral] name] compare:peripheral.name] == NSOrderedSame)
            return YES;
        return NO;
    };
    
    PeripheralCell* cell;
    NSUInteger t=[peripherals indexOfObjectPassingTest:test];
    if(t!= NSNotFound)
    {
        cell=[peripherals objectAtIndex:t];
        cell.peripheral=peripheral;
        cell.rssi=RSSI;
        [scannedResultTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:t inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }else{
        cell=[[PeripheralCell alloc] init];
        [peripherals addObject: cell];
        cell.peripheral=peripheral;
        cell.rssi=RSSI;
        [scannedResultTable insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[peripherals count]-1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    }

}

-(void) updatedRSSI:(CBPeripheral *)peripheral {

}

- (void) discover_services{
    NSArray *keys = [NSArray arrayWithObjects:
                     [CBUUID UUIDWithString:IPS_DATA_SERVICE], //@"0bd51666-e7cb-469b-8e4d-2742f1ba77cc"],
                     nil];
    NSArray *objects = [NSArray arrayWithObjects:
                        @"IPS Data Service", //Was Bluegiga Cable Replacement
                        nil];
    
    serviceNames = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    
    [connected_peripheral discoverServices:[serviceNames allKeys]];
}

- (void) connectedPeripheral:(CBPeripheral *)peripheral {
    connected_peripheral = peripheral;
    [connected_peripheral setDelegate:self];
    [self discover_services];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if(error != nil)
    {
        //TODO: handle error
        return;
    }
    
    NSEnumerator *e = [service.characteristics objectEnumerator];
    
    if ( (homevc_characteristic = [e nextObject]) ) {
        [peripheral setNotifyValue:YES forCharacteristic: homevc_characteristic];
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
        [connected_peripheral discoverCharacteristics:[NSArray arrayWithObject:[CBUUID UUIDWithString:IPS_DATA_SERVICE /*@"0bd51666-e7cb-469b-8e4d-2742f1ba77cc"*/]] forService:service];
    }
}

- (void) updatedCharacteristic:(CBPeripheral *)peripheral sUUID:(CBUUID *)sUUID cUUID:(CBUUID *)cUUID data:(NSData *)data
{

}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error != nil)
        return;

    //NSLog(@"characteristic.value.length=%d", characteristic.value.length);
    NSLog(@"characteristic.value=%@", characteristic.value);
    //dbgTextView.text = @"";
    //[self updateLog:[NSString stringWithFormat:@"characteristic.value=%@", characteristic.value]];
/*

#define NUM_TOTAL_PACKET_BYTES  20
#define BUFFER_PACKETS_TO_HOLD  2
    
    unsigned char buffer[NUM_TOTAL_PACKET_BYTES * BUFFER_PACKETS_TO_HOLD ] = {0};
    
    //  unsigned long result = crc32(0, characteristic.value.bytes, characteristic.value.length);
    //    NSLog(@"CRC32: %lu", result);
    
    int len=characteristic.value.length;
    memcpy(buffer,[characteristic.value bytes],len);
    buffer[len]=0;
    
    if(len != 0){
        
        if(strncmp(buffer, "room1", 5) == 0){
            //NSLog(@"a: %@",a);
            //urlString = [NSString stringWithFormat: @"http://10.0.9.149:3000/api/set_data/%@", a];
            NSString *urlString = [NSString stringWithFormat: @"http://10.0.9.149:3000/api/set_data/room1"];
            // Create the request.
            NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                      cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                  timeoutInterval:60.0];
            // create the connection with the request
            // and start loading the data
            int nothing = 0;
            NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
            if (theConnection) {
                // Create the NSMutableData to hold the received data.
                // receivedData is an instance variable declared elsewhere.
                //receivedData = [[NSMutableData data] retain];
                nothing++;
                ;
            } else {
                // Inform the user that the connection failed.
                nothing--;
                NSLog(@"Connection failed.");
                ;
            }
            [self updateLog:[NSString stringWithFormat:@"room1"]];
            //textRx.text= [NSString stringWithFormat:@"room1"];
        }
        else if(strncmp(buffer, "room2", 5) == 0){
            //NSLog(@"a: %@",a);
            NSString *urlString = [NSString stringWithFormat: @"http://10.0.9.149:3000/api/set_data/room2"];
            //urlString = [NSString stringWithFormat: @"http://10.0.9.149:3000/api/set_data/%@", a];
            // Create the request.
            NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                      cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                  timeoutInterval:60.0];
            // create the connection with the request
            // and start loading the data
            int nothing = 0;
            NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
            if (theConnection) {
                // Create the NSMutableData to hold the received data.
                // receivedData is an instance variable declared elsewhere.
                //receivedData = [[NSMutableData data] retain];
                nothing++;
                ;
            } else {
                // Inform the user that the connection failed.
                nothing--;
                NSLog(@"Connection failed.");
                ;
            }
            [self updateLog:[NSString stringWithFormat:@"room2"]];
            //textRx.text= [NSString stringWithFormat:@"room2"];
        }
        
 
    }
 
 */
}

-(BOOL) textFieldShouldReturn:(UITextField *)textField{
    
    [textField resignFirstResponder];
    return YES;
}


@end
