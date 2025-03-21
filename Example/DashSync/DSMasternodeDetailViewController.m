//
//  DSMasternodeDetailViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/21/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSMasternodeDetailViewController.h"
#import "BRCopyLabel.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSProviderUpdateRegistrarTransactionsViewController.h"
#import "DSProviderUpdateServiceTransactionsViewController.h"
#import "DSReclaimMasternodeViewController.h"
#import "DSUpdateMasternodeRegistrarViewController.h"
#import "DSUpdateMasternodeServiceViewController.h"
#import <arpa/inet.h>

@interface DSMasternodeDetailViewController ()
@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (strong, nonatomic) IBOutlet UILabel *operatorKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *operatorPublicKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *ownerKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *votingKeyLabel;
@property (strong, nonatomic) IBOutlet UILabel *votingAddressLabel;
@property (strong, nonatomic) IBOutlet UILabel *fundsInHoldingLabel;
@property (strong, nonatomic) IBOutlet UILabel *activeLabel;
@property (strong, nonatomic) IBOutlet UILabel *payToAddress;
@property (strong, nonatomic) IBOutlet BRCopyLabel *proRegTxLabel;
@property (strong, nonatomic) IBOutlet BRCopyLabel *proUpRegTxLabel;
@property (strong, nonatomic) IBOutlet BRCopyLabel *proUpServTxLabel;

@end

@implementation DSMasternodeDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    dashcore_sml_masternode_list_entry_MasternodeListEntry *entry = self.simplifiedMasternodeEntry->masternode_list_entry;
    u128 *ip_address = DSocketAddrIp(entry->service_address);
    uint16_t port = DSocketAddrPort(entry->service_address);
    UInt128 ipAddress = u128_cast(ip_address);

    char s[INET6_ADDRSTRLEN];
    uint32_t ipAddressu32 = ipAddress.u32[3];
    
    char *voting_address = DMasternodeEntryVotingAddress(self.simplifiedMasternodeEntry->masternode_list_entry->key_id_voting, self.chain.chainType);
    self.locationLabel.text = [NSString stringWithFormat:@"%s:%d", inet_ntop(AF_INET, &ipAddressu32, s, sizeof(s)), port];
    self.ownerKeyLabel.text = self.localMasternode.ownerKeysWallet ? @"SHOW" : @"NO";
    self.operatorKeyLabel.text = self.localMasternode.operatorKeysWallet ? @"SHOW" : @"NO";
    self.operatorPublicKeyLabel.text = uint384_hex(u384_cast(self.simplifiedMasternodeEntry->masternode_list_entry->operator_public_key->_0));
    self.votingAddressLabel.text = [DSKeyManager NSStringFrom:voting_address];
    self.votingKeyLabel.text = self.localMasternode.votingKeysWallet ? @"SHOW" : @"NO";
    self.fundsInHoldingLabel.text = self.localMasternode.holdingKeysWallet ? @"YES" : @"NO";
    self.activeLabel.text = self.simplifiedMasternodeEntry->masternode_list_entry->is_valid ? @"YES" : @"NO";
    self.payToAddress.text = self.localMasternode.payoutAddress ? self.localMasternode.payoutAddress : @"Unknown";
    self.proRegTxLabel.text = uint256_hex(self.localMasternode.providerRegistrationTransaction.txHash);
    self.proUpRegTxLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.localMasternode.providerUpdateRegistrarTransactions.count];
    self.proUpServTxLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.localMasternode.providerUpdateServiceTransactions.count];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"UpdateMasternodeServiceSegue"]) {
        UINavigationController *navigationController = (UINavigationController *)segue.destinationViewController;
        DSUpdateMasternodeServiceViewController *updateMasternodeServiceViewController = (DSUpdateMasternodeServiceViewController *)navigationController.topViewController;
        updateMasternodeServiceViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"UpdateMasternodeRegistrarSegue"]) {
        UINavigationController *navigationController = (UINavigationController *)segue.destinationViewController;
        DSUpdateMasternodeRegistrarViewController *updateMasternodeRegistrarViewController = (DSUpdateMasternodeRegistrarViewController *)navigationController.topViewController;
        updateMasternodeRegistrarViewController.localMasternode = self.localMasternode;
        updateMasternodeRegistrarViewController.simplifiedMasternodeEntry = self.simplifiedMasternodeEntry;
    } else if ([segue.identifier isEqualToString:@"ReclaimMasternodeSegue"]) {
        UINavigationController *navigationController = (UINavigationController *)segue.destinationViewController;
        DSReclaimMasternodeViewController *reclaimMasternodeViewController = (DSReclaimMasternodeViewController *)navigationController.topViewController;
        reclaimMasternodeViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"ShowProviderUpdateRegistrarTransactionsSegue"]) {
        DSProviderUpdateRegistrarTransactionsViewController *providerUpdateRegistrarTransactionsViewController = segue.destinationViewController;
        providerUpdateRegistrarTransactionsViewController.localMasternode = self.localMasternode;
    } else if ([segue.identifier isEqualToString:@"ShowProviderUpdateServiceTransactionsSegue"]) {
        DSProviderUpdateServiceTransactionsViewController *providerUpdateServiceTransactionsViewController = segue.destinationViewController;
        providerUpdateServiceTransactionsViewController.localMasternode = self.localMasternode;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 2:
                    if (self.localMasternode.ownerKeysWallet && [self.ownerKeyLabel.text isEqualToString:@"SHOW"]) {
                        [self.localMasternode.ownerKeysWallet seedWithPrompt:@"Show owner key?"
                                                                   forAmount:0
                                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                                      if (seed) {
                                                                          DMaybeOpaqueKey *key = [self.localMasternode ownerKeyFromSeed:seed];
                                                                          self.ownerKeyLabel.text = [DSKeyManager serializedPrivateKey:key->ok chainType:self.chain.chainType];
                                                                      }
                                                                  }];
                    }
                    break;
                case 3:
                    if (self.localMasternode.operatorKeysWallet && [self.operatorKeyLabel.text isEqualToString:@"SHOW"]) {
                        [self.localMasternode.operatorKeysWallet seedWithPrompt:@"Show operator key?"
                                                                      forAmount:0
                                                                     completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                                         if (seed) {
                                                                             self.operatorKeyLabel.text = [self.localMasternode operatorKeyStringFromSeed:seed];
                                                                         }
                                                                     }];
                    }
                    break;
                case 4:
                    if (self.localMasternode.operatorKeysWallet && [self.votingKeyLabel.text isEqualToString:@"SHOW"]) {
                        [self.localMasternode.operatorKeysWallet seedWithPrompt:@"Show voting key?"
                                                                      forAmount:0
                                                                     completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                                                         if (seed) {
                                                                             self.votingKeyLabel.text = [self.localMasternode votingKeyStringFromSeed:seed];
                                                                         }
                                                                     }];
                    }
                    break;

                default:
                    break;
            }

        } break;
        case 1: {
            switch (indexPath.row) {
                case 0: {
                    if (!self.localMasternode) {
                        [self claimSimplifiedMasternodeEntry];
                    }
                }
                default:
                    break;
            }
        }
        default:
            break;
    }
}

- (void)claimSimplifiedMasternodeEntry {
    u256 *pro_tx_hash = dashcore_hash_types_ProTxHash_inner(self.simplifiedMasternodeEntry->masternode_list_entry->pro_reg_tx_hash);
    UInt256 reversedProTxHash = uint256_reverse(u256_cast(pro_tx_hash));
    u256_dtor(pro_tx_hash);
    [[DSInsightManager sharedInstance] queryInsightForTransactionWithHash:reversedProTxHash
                                                                  onChain:self.chain
                                                               completion:^(DSTransaction *transaction, NSError *error) {
        if ([transaction isKindOfClass:[DSProviderRegistrationTransaction class]]) {
            DSProviderRegistrationTransaction *providerRegistrationTransaction = (DSProviderRegistrationTransaction *)transaction;
            [self.chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:providerRegistrationTransaction save:TRUE];
        }
    }];


    //    [self.moc performBlockAndWait:^{ // add the transaction to core data
    //        [DSChainEntity setContext:self.moc];
    //        Class transactionEntityClass = [transaction entityClass];
    //        [transactionEntityClass setContext:self.moc];
    //        [DSTransactionHashEntity setContext:self.moc];
    //        [DSAddressEntity setContext:self.moc];
    //        if ([DSTransactionEntity countObjectsInContext:context matching:@"transactionHash.txHash == %@", uint256_data(txHash)] == 0) {
    //
    //            DSTransactionEntity * transactionEntity = [transactionEntityClass managedObject];
    //            [transactionEntity setAttributesFromTransaction:transaction];
    //            [transactionEntityClass saveContext];
    //        }
    //    }];

    //    uint32_t votingIndex;
    //    DSWallet * votingWallet = [self.simplifiedMasternodeEntry.chain walletHavingProviderVotingAuthenticationHash:self.simplifiedMasternodeEntry.keyIDVoting foundAtIndex:&votingIndex];
    //
    //    uint32_t operatorIndex;
    //    DSWallet * operatorWallet = [self.simplifiedMasternodeEntry.chain walletHavingProviderOperatorAuthenticationKey:self.simplifiedMasternodeEntry.operatorPublicKey foundAtIndex:&operatorIndex];
    //
}


@end
