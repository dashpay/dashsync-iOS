//
//  DSBlockchainUserActionsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSBlockchainUserActionsViewController.h"
#import "DSTopupBlockchainUserViewController.h"

@interface DSBlockchainUserActionsViewController ()

@end

@implementation DSBlockchainUserActionsViewController

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

-(void)raiseIssue:(NSString*)issue message:(NSString*)message {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:issue message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alert animated:TRUE completion:^{
        
    }];
}

-(IBAction)reset:(id)sender {
    [self.blockchainUser resetTransactionUsingNewIndex:self.blockchainUser.wallet.unusedBlockchainUserIndex completion:^(DSBlockchainUserResetTransaction *blockchainUserResetTransaction) {
        [self.chainPeerManager publishTransaction:blockchainUserResetTransaction completion:^(NSError * _Nullable error) {
            if (error) {
                [self raiseIssue:@"Error" message:error.localizedDescription];
                
            } else {
                [self.navigationController popViewControllerAnimated:TRUE];
            }
        }];
    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1) {
        [self reset:self];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainUserTopupSegue"]) {
        DSTopupBlockchainUserViewController * topupBlockchainUserViewController = (DSTopupBlockchainUserViewController*)segue.destinationViewController;
        topupBlockchainUserViewController.chainPeerManager = self.chainPeerManager;
        topupBlockchainUserViewController.blockchainUser = self.blockchainUser;
    }
}

@end
