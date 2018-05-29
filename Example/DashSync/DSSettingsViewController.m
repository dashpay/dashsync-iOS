//
//  DSSettingsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSSettingsViewController.h"

@interface DSSettingsViewController ()

@property (strong, nonatomic) IBOutlet UISwitch *syncSPV;

@property (strong, nonatomic) IBOutlet UISwitch *fullBlocksSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *syncMNListSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *syncSporksSwitch;

@end

@implementation DSSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
