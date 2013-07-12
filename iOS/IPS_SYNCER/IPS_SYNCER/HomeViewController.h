//
//  HomeViewController.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PacketParser.h"
#import "SensorToServerStateMachine.h"

@interface HomeViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate, SensorToServerStateMachineDelegate>
{
    NSMutableArray *peripherals;
    SensorToServerStateMachine *state_machine;
}


@property (strong, nonatomic) IBOutlet UITableView* scannedResultTable;
@property (strong, nonatomic) IBOutlet UITextView *dbgTextView;
@property (strong, nonatomic) IBOutlet UITextField *seqNumTextField;

@end
