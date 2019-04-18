//
//  DSDAPICallsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 9/13/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSDAPICallsViewController.h"
#import "BRBubbleView.h"
#import "DSDAPIGetAddressSummaryViewController.h"
#import "DSDAPIGetUserInfoViewController.h"

@interface DSDAPICallsViewController ()

@end

@implementation DSDAPICallsViewController

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

-(void)getBestBlockHeight:(id)sender {
    [self.chainManager.DAPIClient.DAPINetworkService getBestBlockHeightSuccess:^(NSNumber * _Nonnull blockHeight) {
        [self.view addSubview:[[[BRBubbleView viewWithText:[NSString stringWithFormat:@"%@",blockHeight]
                                                    center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                               popOutAfterDelay:2.0]];
    } failure:^(NSError * _Nonnull error) {
        [self.view addSubview:[[[BRBubbleView viewWithText:[NSString stringWithFormat:@"%@",error.localizedDescription]
                                                    center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                               popOutAfterDelay:2.0]];
    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0:
                    [self getBestBlockHeight:self];
                    break;
                    
                default:
                    break;
            }
            break;
            
        default:
            break;
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"GetAddressSummarySegue"]) {
        DSDAPIGetAddressSummaryViewController * DAPIGetAddressSummaryViewController = (DSDAPIGetAddressSummaryViewController*)segue.destinationViewController;
        DAPIGetAddressSummaryViewController.chainManager = self.chainManager;
    } else if ([segue.identifier isEqualToString:@"GetUserInfoSegue"]) {
        DSDAPIGetUserInfoViewController * DAPIGetUserInfoViewController = (DSDAPIGetUserInfoViewController*)segue.destinationViewController;
        DAPIGetUserInfoViewController.chainManager = self.chainManager;
    }
}




@end
