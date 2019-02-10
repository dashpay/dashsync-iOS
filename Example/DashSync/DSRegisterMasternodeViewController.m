//
//  DSRegisterMasternodeViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 2/9/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSRegisterMasternodeViewController.h"
#import "DSKeyValueTableViewCell.h"
#import "DSAccountChooserTableViewCell.h"
#import "DSWalletChooserTableViewCell.h"

@interface DSRegisterMasternodeViewController ()

@property (nonatomic,strong) DSKeyValueTableViewCell * ipAddressTableViewCell;
@property (nonatomic,strong) DSKeyValueTableViewCell * portTableViewCell;
@property (nonatomic,strong) DSAccountChooserTableViewCell * accountChooserTableViewCell;
@property (nonatomic,strong) DSWalletChooserTableViewCell * walletChooserTableViewCell;
@property (nonatomic,strong) DSAccount * account;
@property (nonatomic,strong) DSWallet * wallet;

@end

@implementation DSRegisterMasternodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.ipAddressTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeIPAddressCellIdentifier"];
    self.portTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodePortCellIdentifier"];
    self.portTableViewCell.valueTextField.text = @"19999";
    self.accountChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeFundingAccountCellIdentifier"];
    self.walletChooserTableViewCell = [self.tableView dequeueReusableCellWithIdentifier:@"MasternodeWalletCellIdentifier"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                    return self.ipAddressTableViewCell;
                case 1:
                    return self.portTableViewCell;
                case 2:
                    return self.accountChooserTableViewCell;
                case 3:
                    return self.walletChooserTableViewCell;
            }
        }
    }
    return nil;
}

-(IBAction)registerMasternode:(id)sender {
    DSLocalMasternode * masternode = [[DSLocalMasternode alloc] init];
}

-(void)viewController:(UIViewController*)controller didChooseAccount:(DSAccount*)account {
    self.account = account;
    self.accountChooserTableViewCell.accountLabel.text = [NSString stringWithFormat:@"%@-%u",self.account.wallet.uniqueID,self.account.accountNumber];
}

-(void)viewController:(UIViewController *)controller didChooseWallet:(DSWallet *)wallet {
    self.wallet = wallet;
    self.walletChooserTableViewCell.walletLabel.text = [NSString stringWithFormat:@"%@",self.wallet.uniqueID];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseFundingAccountSegue"]) {
        DSAccountChooserViewController * chooseAccountSegue = (DSAccountChooserViewController*)segue.destinationViewController;
        chooseAccountSegue.chain = self.chain;
        chooseAccountSegue.minAccountBalanceNeeded = MASTERNODE_COST;
        chooseAccountSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"ChooseWalletSegue"]) {
        DSWalletChooserViewController * chooseWalletSegue = (DSWalletChooserViewController*)segue.destinationViewController;
        chooseWalletSegue.chain = self.chain;
        chooseWalletSegue.delegate = self;
    }
}

-(IBAction)cancel {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}
                    
@end
