//
//  DSUpdateMasternodeRegistrarViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/22/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSUpdateMasternodeRegistrarViewController.h"
#import "DSKeyValueTableViewCell.h"
#import "DSAccountChooserTableViewCell.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSLocalMasternode.h"
#include <arpa/inet.h>

@interface DSUpdateMasternodeRegistrarViewController ()

@property (nonatomic,strong) DSKeyValueTableViewCell * payoutTableViewCell;
@property (nonatomic,strong) DSAccountChooserTableViewCell * accountChooserTableViewCell;
@property (nonatomic,strong) DSAccount * account;

@end

@implementation DSUpdateMasternodeRegistrarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.payoutTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodePayoutAddressCellIdentifier"];
    self.accountChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeFundingAccountCellIdentifier"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                    return self.payoutTableViewCell;
                case 1:
                    return self.accountChooserTableViewCell;
            }
        }
    }
    return nil;
}

-(IBAction)updateMasternode:(id)sender {

    [self.localMasternode updateTransactionFundedByAccount:self.account changeOperator:self.localMasternode.providerRegistrationTransaction.operatorKey changeVotingKeyHash:self.localMasternode.providerRegistrationTransaction.votingKeyHash changePayoutAddress:self.payoutTableViewCell.valueTextField.text completion:^(DSProviderUpdateRegistrarTransaction * _Nonnull providerUpdateRegistrarTransaction) {
        
        if (providerUpdateRegistrarTransaction) {
            [self.account signTransaction:providerUpdateRegistrarTransaction withPrompt:@"Would you like to update this masternode?" completion:^(BOOL signedTransaction) {
                if (signedTransaction) {
                    [self.localMasternode.providerRegistrationTransaction.chain.chainManager.transactionManager publishTransaction:providerUpdateRegistrarTransaction completion:^(NSError * _Nullable error) {
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
    if ([segue.identifier isEqualToString:@"ChooseUpdateRegistrarFundingAccountSegue"]) {
        DSAccountChooserViewController * chooseAccountSegue = (DSAccountChooserViewController*)segue.destinationViewController;
        chooseAccountSegue.chain = self.localMasternode.providerRegistrationTransaction.chain;
        chooseAccountSegue.minAccountBalanceNeeded = 1000;
        chooseAccountSegue.delegate = self;
    }
}

-(IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
