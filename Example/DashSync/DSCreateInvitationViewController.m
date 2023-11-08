//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSCreateInvitationViewController.h"
#import "DSAccountChooserViewController.h"
#import "DSBlockchainIdentity.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainInvitation.h"
#import "DSCreditFundingTransaction.h"
#import "DSWalletChooserViewController.h"

@interface DSCreateInvitationViewController ()
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
@property (strong, nonatomic) IBOutlet UITextField *topupAmountLabel;
@property (strong, nonatomic) IBOutlet UITextField *indexLabel;
@property (strong, nonatomic) IBOutlet UILabel *walletIdentifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *fundingAccountIdentifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *typeLabel;
@property (strong, nonatomic) DSWallet *wallet;
@property (strong, nonatomic) DSAccount *fundingAccount;


@end

@implementation DSCreateInvitationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setToDefaultAccount];

    if (self.fundingAccount) {
        self.wallet = self.fundingAccount.wallet;
    }

    self.indexLabel.text = [NSString stringWithFormat:@"%d", [self.wallet unusedBlockchainInvitationIndex]];

    self.topupAmountLabel.text = [NSString stringWithFormat:@"%d", 1000000]; //0.01 Dash
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setToDefaultAccount {
    self.fundingAccount = nil;
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        for (DSAccount *account in wallet.accounts) {
            if (account.balance > 0) {
                self.fundingAccount = account;
                break;
            }
        }
        if (self.fundingAccount) break;
    }
}

- (void)setWallet:(DSWallet *)wallet {
    _wallet = wallet;
    self.walletIdentifierLabel.text = wallet.uniqueIDString;
}

- (void)setFundingAccount:(DSAccount *)fundingAccount {
    _fundingAccount = fundingAccount;
    self.fundingAccountIdentifierLabel.text = fundingAccount.uniqueID;
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

- (IBAction)cancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
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

- (IBAction)done:(id)sender {
    NSScanner *scanner = [NSScanner scannerWithString:self.topupAmountLabel.text];
    uint64_t topupAmount = 0;
    [scanner scanUnsignedLongLong:&topupAmount];
    if (!_wallet) {
        [self raiseIssue:@"No wallet with balance" message:@"To create an invitation you must have a wallet with enough balance to pay the minimum credit fee"];
        return;
    } else if (!_fundingAccount) {
        [self raiseIssue:@"No funding account with balance" message:@"To create an invitation you must have a wallet with enough balance to pay the minimum credit fee"];
        return;
    }
    DSBlockchainInvitation *blockchainInvitation = [self.wallet createBlockchainInvitationUsingDerivationIndex:[self.indexLabel.text intValue]];
    DSBlockchainIdentityRegistrationStep steps = DSBlockchainIdentityRegistrationStep_L1Steps;
    [blockchainInvitation generateBlockchainInvitationsExtendedPublicKeysWithPrompt:@"Update wallet to allow for Evolution features?"
                                                                         completion:^(BOOL registered) {
        [blockchainInvitation.identity createFundingPrivateKeyForInvitationWithPrompt:@"Register?" completion:^(BOOL success, BOOL cancelled) {
            if (success && !cancelled) {
                [blockchainInvitation.identity registerOnNetwork:steps
                                              withFundingAccount:self.fundingAccount
                                                  forTopupAmount:topupAmount
                                                       pinPrompt:@"Enter your PIN?"
                                                  stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {}
                                                      completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *_Nonnull error) {
                    if (error) {
                        [self raiseIssue:@"Error" message:error.localizedDescription];
                        return;
                    } else {
                        [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
                    }
                }];
            }
        }];
    }];
}

- (void)viewController:(UIViewController *)controller didChooseWallet:(DSWallet *)wallet {
    self.wallet = wallet;
}

- (void)viewController:(UIViewController *)controller didChooseAccount:(DSAccount *)account {
    self.fundingAccount = account;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainInvitationChooseWalletSegue"]) {
        DSWalletChooserViewController *chooseWalletSegue = (DSWalletChooserViewController *)segue.destinationViewController;
        chooseWalletSegue.chain = self.chainManager.chain;
        chooseWalletSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"BlockchainInvitationChooseAccountSegue"]) {
        DSAccountChooserViewController *chooseAccountSegue = (DSAccountChooserViewController *)segue.destinationViewController;
        chooseAccountSegue.chain = self.chainManager.chain;
        chooseAccountSegue.delegate = self;
    }
}


@end
