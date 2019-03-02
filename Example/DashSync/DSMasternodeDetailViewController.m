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
#import "DSUpdateMasternodeRegistrarViewController.h"
#import "DSReclaimMasternodeViewController.h"
#import "DSProviderUpdateRegistrarTransactionsViewController.h"
#import "DSProviderUpdateServiceTransactionsViewController.h"
#import <arpa/inet.h>
#import "BRCopyLabel.h"

@interface DSMasternodeDetailViewController ()
@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (strong, nonatomic) IBOutlet UILabel *operatorKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *ownerKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *votingKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *fundsInHoldingLabel;
@property (strong, nonatomic) IBOutlet UILabel *payToAddress;
@property (strong, nonatomic) IBOutlet BRCopyLabel *proRegTxLabel;
@property (strong, nonatomic) IBOutlet BRCopyLabel *proUpRegTxLabel;
@property (strong, nonatomic) IBOutlet BRCopyLabel *proUpServTxLabel;

@end

@implementation DSMasternodeDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    char s[INET6_ADDRSTRLEN];
    uint32_t ipAddress = self.simplifiedMasternodeEntry.address.u32[3];
    
    self.locationLabel.text = [NSString stringWithFormat:@"%s:%d",inet_ntop(AF_INET, &ipAddress, s, sizeof(s)),self.simplifiedMasternodeEntry.port];
    self.ownerKeyLabel.text = self.localMasternode.ownerKeysWallet?@"SHOW":@"NO";
    self.operatorKeyLabel.text = self.localMasternode.operatorKeysWallet?@"SHOW":@"NO";
    self.votingKeyLabel.text = self.localMasternode.votingKeysWallet?@"SHOW":@"NO";
    self.fundsInHoldingLabel.text = self.localMasternode.holdingKeysWallet?@"YES":@"NO";
    self.payToAddress.text = self.localMasternode.payoutAddress?self.localMasternode.payoutAddress:@"Unknown";
    self.proRegTxLabel.text = uint256_hex(self.localMasternode.providerRegistrationTransaction.txHash);
    self.proUpRegTxLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)self.localMasternode.providerUpdateRegistrarTransactions.count];
    self.proUpServTxLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)self.localMasternode.providerUpdateServiceTransactions.count];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"UpdateMasternodeServiceSegue"]) {
        UINavigationController * navigationController = (UINavigationController*)segue.destinationViewController;
        DSUpdateMasternodeServiceViewController * updateMasternodeServiceViewController = (DSUpdateMasternodeServiceViewController*)navigationController.topViewController;
        updateMasternodeServiceViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"UpdateMasternodeRegistrarSegue"]) {
        UINavigationController * navigationController = (UINavigationController*)segue.destinationViewController;
        DSUpdateMasternodeRegistrarViewController * updateMasternodeRegistrarViewController = (DSUpdateMasternodeRegistrarViewController*)navigationController.topViewController;
        updateMasternodeRegistrarViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"ReclaimMasternodeSegue"]) {
        UINavigationController * navigationController = (UINavigationController*)segue.destinationViewController;
        DSReclaimMasternodeViewController * reclaimMasternodeViewController = (DSReclaimMasternodeViewController*)navigationController.topViewController;
        reclaimMasternodeViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"ShowProviderUpdateRegistrarTransactionsSegue"]) {
        DSProviderUpdateRegistrarTransactionsViewController * providerUpdateRegistrarTransactionsViewController = segue.destinationViewController;
        providerUpdateRegistrarTransactionsViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"ShowProviderUpdateServiceTransactionsSegue"]) {
        DSProviderUpdateServiceTransactionsViewController * providerUpdateServiceTransactionsViewController = segue.destinationViewController;
        providerUpdateServiceTransactionsViewController.localMasternode = self.localMasternode;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 2:
                    if (self.localMasternode.ownerKeysWallet) {
                        [self.localMasternode.ownerKeysWallet seedWithPrompt:@"Show owner key?" forAmount:0 completion:^(NSData * _Nullable seed, BOOL cancelled) {
                            if (seed) {
                                self.ownerKeyLabel.text = [self.localMasternode ownerKeyStringFromSeed:seed];
                            }
                        }];
                    }
                    break;
                case 3:
                    if (self.localMasternode.operatorKeysWallet) {
                        [self.localMasternode.operatorKeysWallet seedWithPrompt:@"Show operator key?" forAmount:0 completion:^(NSData * _Nullable seed, BOOL cancelled) {
                            if (seed) {
                                self.operatorKeyLabel.text = [self.localMasternode operatorKeyStringFromSeed:seed];
                            }
                        }];
                    }
                    break;
                case 4:
                    if (self.localMasternode.operatorKeysWallet) {
                        [self.localMasternode.operatorKeysWallet seedWithPrompt:@"Show voting key?" forAmount:0 completion:^(NSData * _Nullable seed, BOOL cancelled) {
                            if (seed) {
                                self.votingKeyLabel.text = [self.localMasternode votingKeyStringFromSeed:seed];
                            }
                        }];
                    }
                    break;
                    
                default:
                    break;
            }
            
        }
            break;
            
        default:
            break;
    }
}


@end
