//
//  HomeViewController.h
//  IPS_SYNCER
//
//  Created by Lucas Sun on 7/9/13.
//  Copyright (c) 2013 CMU SV. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CBCentralManagerCtrl.h"
#import "CBPeripheralCtrl.h"

@interface HomeViewController : UIViewController <CBPeripheralDelegate, CBCentralManagerCtrlDelegate, CBPeripheralCtrlDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate>
{
    NSMutableArray *peripherals;
    CBPeripheral *connected_peripheral;
    
    NSDictionary *serviceNames;
    CBCharacteristic *homevc_characteristic;
}


@property (strong,nonatomic) CBCentralManagerCtrl *CBCMCtrl;
@property (strong,nonatomic) CBPeripheralCtrl *CBPCtrl;
@property (strong, nonatomic) IBOutlet UITableView* scannedResultTable;
@property (strong, nonatomic) IBOutlet UITextView *dbgTextView;
@property (strong, nonatomic) IBOutlet UITextField *seqNumTextField;

@end
