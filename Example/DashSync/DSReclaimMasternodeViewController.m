//
//  DSReclaimMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/28/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSReclaimMasternodeViewController.h"
#import "DSKeyValueTableViewCell.h"
#import "DSAccountChooserTableViewCell.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSLocalMasternode.h"
#import "DSDerivationPathFactory.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#include <arpa/inet.h>

@interface DSReclaimMasternodeViewController () <DSAccountChooserDelegate>

@property (nonatomic,strong) DSAccountChooserTableViewCell * accountChooserTableViewCell;
@property (nonatomic,strong) DSAccount * account;

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

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                    return self.accountChooserTableViewCell;
            }
        }
    }
    return nil;
}

-(IBAction)reclaimMasternode:(id)sender {
    [self.localMasternode reclaimTransactionToAccount:self.account completion:^(DSTransaction * _Nonnull reclaimTransaction) {
        if (reclaimTransaction) {
            DSMasternodeHoldingsDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:self.localMasternode.holdingKeysWallet];
            [derivationPath signTransaction:reclaimTransaction withPrompt:@"Would you like to update this masternode?" completion:^(BOOL signedTransaction) {
                if (signedTransaction) {
                    [self.localMasternode.providerRegistrationTransaction.chain.chainManager.transactionManager publishTransaction:reclaimTransaction completion:^(NSError * _Nullable error) {
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
            [self raiseIssue:@"Error" message:@"Unable to create Reclaim Transaction."];
        }
    }];
}

-(void)raiseIssue:(NSString*)issue message:(NSString*)message {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:issue message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alert animated:TRUE completion:^{
        
    }];
}

-(void)viewController:(UIViewController*)controller didChooseAccount:(DSAccount*)account {
    self.account = account;
    self.accountChooserTableViewCell.accountLabel.text = [NSString stringWithFormat:@"%@-%u",self.account.wallet.uniqueID,self.account.accountNumber];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseReclaimDestinationAccountSegue"]) {
        DSAccountChooserViewController * chooseAccountSegue = (DSAccountChooserViewController*)segue.destinationViewController;
        chooseAccountSegue.chain = self.localMasternode.providerRegistrationTransaction.chain;
        chooseAccountSegue.minAccountBalanceNeeded = 200;
        chooseAccountSegue.delegate = self;
    }
}

-(IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
