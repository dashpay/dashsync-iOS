//
//  DSUpdateMasternodeRegistrarViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/22/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSUpdateMasternodeRegistrarViewController.h"
#import "DSAccountChooserTableViewCell.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSKeyValueTableViewCell.h"
#import "DSLocalMasternode.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSWalletChooserTableViewCell.h"
#include <arpa/inet.h>

@interface DSUpdateMasternodeRegistrarViewController ()

@property (nonatomic, strong) DSKeyValueTableViewCell *payoutTableViewCell;
@property (nonatomic, strong) DSAccountChooserTableViewCell *accountChooserTableViewCell;
@property (nonatomic, strong) DSWalletChooserTableViewCell *walletChooserTableViewCell;
@property (nonatomic, strong) DSAccount *account;
@property (nonatomic, strong) DSWallet *votingWallet;

@end

@implementation DSUpdateMasternodeRegistrarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.payoutTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodePayoutAddressCellIdentifier"];
    self.accountChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeFundingAccountCellIdentifier"];
    self.walletChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeVotingWalletCellIdentifier"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0:
                    return self.payoutTableViewCell;
                case 1:
                    return self.walletChooserTableViewCell;
                case 2:
                    return self.accountChooserTableViewCell;
            }
        }
    }
    return nil;
}

- (IBAction)updateMasternode:(id)sender {
    UInt160 votingHash ;
    if (self.votingWallet) {
        DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self.votingWallet];
        votingHash = providerVotingKeysDerivationPath.firstUnusedPublicKey.hash160;
    } else {
        u160 *key_id_voting = dashcore_hash_types_PubkeyHash_inner(self.simplifiedMasternodeEntry->masternode_list_entry->key_id_voting);
        votingHash = u160_cast(key_id_voting);
        u160_dtor(key_id_voting);
    }
    NSString *payoutAddress = (self.payoutTableViewCell.valueTextField.text && ![self.payoutTableViewCell.valueTextField.text isEqualToString:@""]) ? self.payoutTableViewCell.valueTextField.text : self.localMasternode.payoutAddress;
    [self.localMasternode updateTransactionFundedByAccount:self.account
                                            changeOperator:self.localMasternode.providerRegistrationTransaction.operatorKey
                                       changeVotingKeyHash:votingHash
                                       changePayoutAddress:payoutAddress
                                                completion:^(DSProviderUpdateRegistrarTransaction *_Nonnull providerUpdateRegistrarTransaction) {
                                                    if (providerUpdateRegistrarTransaction) {
                                                        [self.account signTransaction:providerUpdateRegistrarTransaction
                                                                           withPrompt:@"Would you like to update this masternode?"
                                                                           completion:^(BOOL signedTransaction, BOOL cancelled) {
                                                                               if (signedTransaction) {
                                                                                   [self.localMasternode.providerRegistrationTransaction.chain.chainManager.transactionManager publishTransaction:providerUpdateRegistrarTransaction
                                                                                                                                                                                       completion:^(NSError *_Nullable error) {
                                                                                                                                                                                           if (error) {
                                                                                                                                                                                               [self raiseIssue:@"Error" message:error.localizedDescription];
                                                                                                                                                                                           } else {
                                                                                                                                                                                               //[masternode registerInWallet];
                                                                                                                                                                                               [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
                                                                                                                                                                                           }
                                                                                                                                                                                       }];
                                                                               } else {
                                                                                   [self raiseIssue:@"Error" message:@"Transaction was not signed."];
                                                                               }
                                                                           }];
                                                    } else {
                                                        [self raiseIssue:@"Error" message:@"Unable to create ProviderRegistrationTransaction."];
                                                    }
                                                }];
}

- (void)raiseIssue:(NSString *)issue message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:issue message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *_Nonnull action){

                                            }]];
    [self presentViewController:alert
                       animated:TRUE
                     completion:^{

                     }];
}

- (void)viewController:(UIViewController *)controller didChooseAccount:(DSAccount *)account {
    self.account = account;
    self.accountChooserTableViewCell.accountLabel.text = [NSString stringWithFormat:@"%@-%u", self.account.wallet.uniqueIDString, self.account.accountNumber];
}

- (void)viewController:(UIViewController *)controller didChooseWallet:(DSWallet *)wallet {
    self.votingWallet = wallet;
    self.walletChooserTableViewCell.walletLabel.text = [NSString stringWithFormat:@"%@", self.votingWallet.uniqueIDString];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseUpdateRegistrarFundingAccountSegue"]) {
        DSAccountChooserViewController *chooseAccountSegue = (DSAccountChooserViewController *)segue.destinationViewController;
        chooseAccountSegue.chain = self.localMasternode.providerRegistrationTransaction.chain;
        chooseAccountSegue.minAccountBalanceNeeded = 1000;
        chooseAccountSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"ChooseVotingWalletSegue"]) {
        DSWalletChooserViewController *chooseWalletSegue = (DSWalletChooserViewController *)segue.destinationViewController;
        chooseWalletSegue.chain = self.localMasternode.providerRegistrationTransaction.chain;
        chooseWalletSegue.delegate = self;
    }
}

- (IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
