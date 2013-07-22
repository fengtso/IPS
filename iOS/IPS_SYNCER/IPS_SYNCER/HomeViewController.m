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

@synthesize dbgTextView, scannedResultTable, startBtn;

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
    
    state_machine = [[SensorToServerStateMachine alloc] init];
    state_machine.delegate = self;
    is_state_machine_on = FALSE;
}

- (void) updateSMLog:(NSString *)text
{
    if (!dbgTextView.hidden) {
        [dbgTextView setText:[NSString stringWithFormat:@"%@%@\r\n",dbgTextView.text,text]];
    }
}

- (void) updateDiscoveredPeripherals:(NSMutableArray *)discovered_peripherals
{
    peripherals = [[NSMutableArray alloc] initWithArray:discovered_peripherals];
    [scannedResultTable reloadData];
}


- (IBAction)scanButtonPressed:(id)sender {
    [peripherals removeAllObjects];
    [scannedResultTable reloadData];
}

- (IBAction)startButtonPressed:(id)sender {
    is_state_machine_on = !is_state_machine_on;
    
    if (is_state_machine_on) {
        [startBtn setTitle:@"Stop" forState:UIControlStateNormal];
        [startBtn setBackgroundColor:[UIColor lightGrayColor]];
        
        [state_machine update_state:@"start_state_machine"];
    }
    else{
        [startBtn setTitle:@"Start" forState:UIControlStateNormal];
        [startBtn setBackgroundColor:[UIColor orangeColor]];

        [state_machine update_state:@"stop_state_machine"];

    }
}

- (IBAction)sendButtonPressed:(id)sender {
    
    
    UIButton* btn = (UIButton*)sender;
    
    if(btn.tag == 1)
       [state_machine send_inquiry_to_sensor:@"loc_data"];
    
    if(btn.tag == 2)
        [state_machine send_ack_start_packet];
    
    if(btn.tag == 3)
        [state_machine send_ack_end_packet];
    
    if(btn.tag == 4)
        [state_machine send_debug_packet];
    
    if(btn.tag == 5)
        [state_machine send_data_to_server:@"loc_packet" :nil];
    
    if (btn.tag == 6) {
        [state_machine send_nack_to_sensor:@"0xaa" :0];
    }
}

- (IBAction)debugConnectBtnPressed:(id)sender
{
    [state_machine update_state:@"start_debug_mode"];
}

- (IBAction)logBtnPressed:(id)sender
{
    dbgTextView.hidden = !dbgTextView.hidden;
}

- (IBAction)clearBtnPressed:(id)sender
{
    dbgTextView.text = @"";
}


- (void) updateLog:(NSString *)text{
    [dbgTextView setText:[NSString stringWithFormat:@"%@%@\r\n",dbgTextView.text,text]];
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
    NSString *peripheral_uuid = [[NSString alloc] initWithFormat:@"%@", pcell.peripheral.UUID];
    NSString *per_uuid = [peripheral_uuid substringWithRange:NSMakeRange(([peripheral_uuid length] - 36), 36)];

    cell.textLabel.text = pcell.peripheral.name;
    cell.detailTextLabel.text = per_uuid;
    //[NSString stringWithFormat:@"RSSI %d",[pcell.rssi intValue]];

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
    
    /*
    if (connected_peripheral) {
        [self.CBCMCtrl.CBCM cancelPeripheralConnection:connected_peripheral];
        connected_peripheral = nil;
    }
    else{
        PeripheralCell* per=[peripherals objectAtIndex:[indexPath row]];
        [self.CBCMCtrl.CBCM connectPeripheral:per.peripheral options:nil];
    }
     */
}



// State Machine delegate function
- (void) discoveredPeripheral:(NSMutableArray *)discovered_peripherals{
    
    peripherals = [[NSMutableArray alloc] initWithArray:discovered_peripherals];
    [scannedResultTable reloadData];
    
}

-(BOOL) textFieldShouldReturn:(UITextField *)textField{
    
    [textField resignFirstResponder];
    return YES;
}


@end
