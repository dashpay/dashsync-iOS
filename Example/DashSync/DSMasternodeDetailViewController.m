//
//  DSMasternodeDetailViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/21/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSMasternodeDetailViewController.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSLocalMasternode.h"
#import "DSUpdateMasternodeServiceViewController.h"
#import <arpa/inet.h>

@interface DSMasternodeDetailViewController ()
@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (strong, nonatomic) IBOutlet UILabel *isOwnerLabel;
@property (strong, nonatomic) IBOutlet UILabel *isOperatorLabel;
@property (strong, nonatomic) IBOutlet UILabel *canVoteLabel;
@property (strong, nonatomic) IBOutlet UILabel *fundsInHoldingLabel;
@property (strong, nonatomic) IBOutlet UILabel *payToAddress;

@end

@implementation DSMasternodeDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    char s[INET6_ADDRSTRLEN];
    uint32_t ipAddress = self.simplifiedMasternodeEntry.address.u32[3];
    
    self.locationLabel.text = [NSString stringWithFormat:@"%s:%d",inet_ntop(AF_INET, &ipAddress, s, sizeof(s)),self.simplifiedMasternodeEntry.port];
    self.isOwnerLabel.text = self.localMasternode.ownerKeysWallet?@"YES":@"NO";
    self.isOperatorLabel.text = self.localMasternode.operatorKeysWallet?@"YES":@"NO";
    self.canVoteLabel.text = self.localMasternode.votingKeysWallet?@"YES":@"NO";
    self.fundsInHoldingLabel.text = self.localMasternode.holdingKeysWallet?@"YES":@"NO";
    self.payToAddress.text = self.localMasternode.payoutAddress?self.localMasternode.payoutAddress:@"Unknown";
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"UpdateMasternodeServiceSegue"]) {
        UINavigationController * navigationController = (UINavigationController*)segue.destinationViewController;
        DSUpdateMasternodeServiceViewController * updateMasternodeServiceViewController = (DSUpdateMasternodeServiceViewController*)navigationController.topViewController;
        updateMasternodeServiceViewController.localMasternode = self.localMasternode;
    }
}


@end
