//
//  DSReclaimMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/28/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSReclaimMasternodeViewController.h"
#import "DSAccountChooserTableViewCell.h"
#import "DSDerivationPathFactory.h"
#import "DSKeyValueTableViewCell.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSWallet+Protected.h"
#include <arpa/inet.h>

@interface DSReclaimMasternodeViewController () <DSAccountChooserDelegate>

@property (nonatomic, strong) DSAccountChooserTableViewCell *accountChooserTableViewCell;
@property (nonatomic, strong) DSAccount *account;

@end

@implementation DSReclaimMasternodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.accountChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeReclaimingAccountCellIdentifier"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0:
                    return self.accountChooserTableViewCell;
            }
        }
    }
    return nil;
}

//// sign any inputs in the given transaction that can be signed using private keys from the wallet
//- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *)authprompt completion:(TransactionValidityCompletionBlock)completion;
//{
//    if ([transaction inputAddresses].count != 1) {
//        completion(NO, NO);
//        return;
//    }
//
//    NSUInteger index = [self indexOfKnownAddress:[[transaction inputAddresses] firstObject]];
//
//    @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
//        self.wallet.secureSeedRequestBlock(authprompt, MASTERNODE_COST, ^void(NSData *_Nullable seed, BOOL cancelled) {
//            if (!seed) {
//                if (completion) completion(NO, cancelled);
//            } else {
//                DMaybeOpaqueKey *key = [self privateKeyAtIndex:(uint32_t)index fromSeed:seed];
//                BOOL signedSuccessfully = [transaction signWithPrivateKeys:@[[NSValue valueWithPointer:key]]];
//                if (completion) completion(signedSuccessfully, NO);
//            }
//        });
//    }
//}
//

- (IBAction)reclaimMasternode:(id)sender {
    [self.localMasternode reclaimTransactionToAccount:self.account
                                           completion:^(DSTransaction *_Nonnull reclaimTransaction) {
        if (reclaimTransaction) {
            DSMasternodeHoldingsDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:self.localMasternode.holdingKeysWallet];
            if ([reclaimTransaction inputAddresses].count != 1) {
                [self raiseIssue:@"Error" message:@"Transaction was not signed."];
                return;
            }
            NSUInteger index = [derivationPath indexOfKnownAddress:[[reclaimTransaction inputAddresses] firstObject]];
            @autoreleasepool { // @autoreleasepool ensures sensitive data will be dealocated immediately
                derivationPath.wallet.secureSeedRequestBlock(@"Would you like to update this masternode?", MASTERNODE_COST, ^void(NSData *_Nullable seed, BOOL cancelled) {
                    if (!seed) {
                        [self raiseIssue:@"Error" message:cancelled ? @"Transaction was cancelled." : @"Transaction was not signed."];
                    } else {
                        DMaybeOpaqueKey *key = [derivationPath privateKeyAtIndex:(uint32_t)index fromSeed:seed];
                        BOOL signedSuccessfully = [reclaimTransaction signWithPrivateKeys:@[[NSValue valueWithPointer:key]]];
                        if (signedSuccessfully) {
                            [self.localMasternode.providerRegistrationTransaction.chain.chainManager.transactionManager publishTransaction:reclaimTransaction
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
                    }
                });
            }
        } else {
            [self raiseIssue:@"Error" message:@"Unable to create Reclaim Transaction."];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseReclaimDestinationAccountSegue"]) {
        DSAccountChooserViewController *chooseAccountSegue = (DSAccountChooserViewController *)segue.destinationViewController;
        chooseAccountSegue.chain = self.localMasternode.providerRegistrationTransaction.chain;
        chooseAccountSegue.minAccountBalanceNeeded = 200;
        chooseAccountSegue.delegate = self;
    }
}

- (IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
