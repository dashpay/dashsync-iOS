//
//  DSRegisterMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/9/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSRegisterMasternodeViewController.h"
#import "DSAccountChooserTableViewCell.h"
#import "DSKeyValueTableViewCell.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSSignPayloadViewController.h"
#import "DSTransactionOutput.h"
#import "DSWalletChooserTableViewCell.h"
#include <arpa/inet.h>

@interface DSRegisterMasternodeViewController ()

@property (nonatomic, strong) DSKeyValueTableViewCell *collateralTransactionTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *collateralIndexTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *ipAddressTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *portTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *payToAddressTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *ownerIndexTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *operatorIndexTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *votingIndexTableViewCell;
@property (nonatomic, strong) DSKeyValueTableViewCell *platformNodeIndexTableViewCell;
@property (nonatomic, strong) DSAccountChooserTableViewCell *accountChooserTableViewCell;
@property (nonatomic, strong) DSWalletChooserTableViewCell *walletChooserTableViewCell;
@property (nonatomic, strong) DSAccount *account;
@property (nonatomic, strong) DSWallet *wallet;
@property (nonatomic, strong) DSProviderRegistrationTransaction *providerRegistrationTransaction;
@property (nonatomic, strong) DSTransaction *collateralTransaction;

@end

@implementation DSRegisterMasternodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.payToAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodePayoutAddressCellIdentifier"];
    self.collateralTransactionTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeCollateralTransactionCellIdentifier"];
    self.collateralIndexTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeCollateralIndexCellIdentifier"];
    self.ipAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeIPAddressCellIdentifier"];
    self.portTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodePortCellIdentifier"];
    self.portTableViewCell.valueTextField.text = [NSString stringWithFormat:@"%d", self.chain.standardPort];
    self.accountChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeFundingAccountCellIdentifier"];
    self.walletChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeWalletCellIdentifier"];
    self.ownerIndexTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeOwnerIndexCellIdentifier"];
    self.votingIndexTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeVotingIndexCellIdentifier"];
    self.platformNodeIndexTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodePlatformNodeIndexCellIdentifier"];
    self.operatorIndexTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeOperatorIndexCellIdentifier"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0:
                    return self.collateralTransactionTableViewCell;
                case 1:
                    return self.collateralIndexTableViewCell;
                case 2:
                    return self.ipAddressTableViewCell;
                case 3:
                    return self.portTableViewCell;
                case 4:
                    return self.ownerIndexTableViewCell;
                case 5:
                    return self.operatorIndexTableViewCell;
                case 6:
                    return self.votingIndexTableViewCell;
                case 7:
                    return self.platformNodeIndexTableViewCell;
                case 8:
                    return self.payToAddressTableViewCell;
                case 9:
                    return self.accountChooserTableViewCell;
                case 10:
                    return self.walletChooserTableViewCell;
            }
        }
    }
    return nil;
}

- (void)signTransactionInputs:(DSProviderRegistrationTransaction *)providerRegistrationTransaction {
    [self.account signTransaction:providerRegistrationTransaction
                       withPrompt:@"Would you like to register this masternode?"
                       completion:^(BOOL signedTransaction, BOOL cancelled) {
                           if (signedTransaction) {
                               [self.chain.chainManager.transactionManager publishTransaction:providerRegistrationTransaction
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
}

- (IBAction)registerMasternode:(id)sender {
    NSString *ipAddressString = [self.ipAddressTableViewCell.valueTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *portString = [self.portTableViewCell.valueTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
    struct in_addr addrV4;
    if (inet_aton([ipAddressString UTF8String], &addrV4) != 0) {
        uint32_t ip = ntohl(addrV4.s_addr);
        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
        DSLogPrivate(@"%08x", ip);
    }
    uint16_t port = [portString intValue];

    uint32_t ownerWalletIndex = UINT32_MAX;
    uint32_t votingWalletIndex = UINT32_MAX;
    uint32_t operatorWalletIndex = UINT32_MAX;
    uint32_t platformNodeWalletIndex = UINT32_MAX;

    if (self.ownerIndexTableViewCell.valueTextField.text && ![self.ownerIndexTableViewCell.valueTextField.text isEqualToString:@""]) {
        ownerWalletIndex = (uint32_t)[self.ownerIndexTableViewCell.valueTextField.text integerValue];
    }

    if (self.operatorIndexTableViewCell.valueTextField.text && ![self.operatorIndexTableViewCell.valueTextField.text isEqualToString:@""]) {
        operatorWalletIndex = (uint32_t)[self.operatorIndexTableViewCell.valueTextField.text integerValue];
    }

    if (self.votingIndexTableViewCell.valueTextField.text && ![self.votingIndexTableViewCell.valueTextField.text isEqualToString:@""]) {
        votingWalletIndex = (uint32_t)[self.votingIndexTableViewCell.valueTextField.text integerValue];
    }
    
    if (self.platformNodeIndexTableViewCell.valueTextField.text && ![self.platformNodeIndexTableViewCell.valueTextField.text isEqualToString:@""]) {
        platformNodeWalletIndex = (uint32_t)[self.platformNodeIndexTableViewCell.valueTextField.text integerValue];
    }

    DSLocalMasternode *masternode = [self.chain.chainManager.masternodeManager createNewMasternodeWithIPAddress:ipAddress onPort:port inFundsWallet:self.wallet fundsWalletIndex:UINT32_MAX inOperatorWallet:self.wallet operatorWalletIndex:operatorWalletIndex inOwnerWallet:self.wallet ownerWalletIndex:ownerWalletIndex inVotingWallet:self.wallet votingWalletIndex:votingWalletIndex inPlatformNodeWallet:self.wallet platformNodeWalletIndex:platformNodeWalletIndex];

    NSString *payoutAddress = DIsValidDashAddress(DChar(self.payToAddressTableViewCell.valueTextField.text), self.chain.chainType) ?
        self.payToAddressTableViewCell.textLabel.text :
        self.account.receiveAddress;


    DSUTXO collateral = DSUTXO_ZERO;
    UInt256 nonReversedCollateralHash = UINT256_ZERO;
    NSString *collateralTransactionHash = self.collateralTransactionTableViewCell.valueTextField.text;
    if (![collateralTransactionHash isEqual:@""]) {
        NSData *collateralTransactionHashData = [collateralTransactionHash hexToData];
        if (collateralTransactionHashData.length != 32) return;
        collateral.hash = collateralTransactionHashData.reverse.UInt256;

        nonReversedCollateralHash = collateralTransactionHashData.UInt256;
        collateral.n = [self.collateralIndexTableViewCell.valueTextField.text integerValue];
    }


    [masternode registrationTransactionFundedByAccount:self.account
                                             toAddress:payoutAddress
                                        withCollateral:collateral
                                            completion:^(DSProviderRegistrationTransaction *_Nonnull providerRegistrationTransaction) {
                                                if (providerRegistrationTransaction) {
                                                    if (dsutxo_is_zero(collateral)) {
                                                        [self signTransactionInputs:providerRegistrationTransaction];
                                                    } else {
                                                        [[DSInsightManager sharedInstance] queryInsightForTransactionWithHash:nonReversedCollateralHash
                                                                                                                      onChain:self.chain
                                                                                                                   completion:^(DSTransaction *transaction, NSError *error) {
                                                                                                                       NSIndexSet *indexSet = [[transaction outputs] indexesOfObjectsPassingTest:^BOOL(DSTransactionOutput *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                                                                                                                           return obj.amount == MASTERNODE_COST;
                                                                                                                       }];
                                                                                                                       if ([indexSet containsIndex:collateral.n]) {
                                                                                                                           self.collateralTransaction = transaction;
                                                                                                                           self.providerRegistrationTransaction = providerRegistrationTransaction;
                                                                                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                               [self performSegueWithIdentifier:@"PayloadSigningSegue" sender:self];
                                                                                                                           });
                                                                                                                       } else {
                                                                                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                               [self raiseIssue:@"Error" message:@"Incorrect collateral index"];
                                                                                                                           });
                                                                                                                       }
                                                                                                                   }];
                                                    }
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
    self.wallet = wallet;
    self.walletChooserTableViewCell.walletLabel.text = [NSString stringWithFormat:@"%@", self.wallet.uniqueIDString];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseFundingAccountSegue"]) {
        DSAccountChooserViewController *chooseAccountSegue = (DSAccountChooserViewController *)segue.destinationViewController;
        chooseAccountSegue.chain = self.chain;
        NSString *collateralString = self.collateralTransactionTableViewCell.valueTextField.text;
        if (!collateralString || [collateralString isEqualToString:@""]) {
            chooseAccountSegue.minAccountBalanceNeeded = (750 + MASTERNODE_COST);
        } else {
            chooseAccountSegue.minAccountBalanceNeeded = 750;
        }
        chooseAccountSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"ChooseWalletSegue"]) {
        DSWalletChooserViewController *chooseWalletSegue = (DSWalletChooserViewController *)segue.destinationViewController;
        chooseWalletSegue.chain = self.chain;
        chooseWalletSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"PayloadSigningSegue"]) {
        DSSignPayloadViewController *signPayloadSegue = (DSSignPayloadViewController *)segue.destinationViewController;
        signPayloadSegue.collateralAddress = self.collateralTransaction.outputs[self.providerRegistrationTransaction.collateralOutpoint.n].address;
        signPayloadSegue.providerRegistrationTransaction = self.providerRegistrationTransaction;
        signPayloadSegue.delegate = self;
    }
}

- (IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)viewController:(nonnull UIViewController *)controller didReturnSignature:(nonnull NSData *)signature {
    self.providerRegistrationTransaction.payloadSignature = signature;
    [self signTransactionInputs:self.providerRegistrationTransaction];
}


@end
