//
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSCreateBlockchainIdentityFromInvitationViewController.h"
#import "DSAccountChooserViewController.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSCreditFundingTransaction.h"
#import "DSWalletChooserViewController.h"

@interface DSCreateBlockchainIdentityFromInvitationViewController ()
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
@property (strong, nonatomic) IBOutlet UITextField *usernameLabel;
@property (strong, nonatomic) IBOutlet UITextField *indexLabel;
@property (strong, nonatomic) IBOutlet UITextField *invitationLinkLabel;
@property (strong, nonatomic) IBOutlet UILabel *walletIdentifierLabel;
@property (strong, nonatomic) IBOutlet UISwitch *registerUsernameSwitch;
@property (strong, nonatomic) DSWallet *wallet;
@property (assign, nonatomic) BOOL shouldRegisterUsername;


@end

@implementation DSCreateBlockchainIdentityFromInvitationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setToDefaultWallet];

    self.shouldRegisterUsername = YES;
    if (uint256_is_zero(self.wallet.chain.dpnsContractID)) {
        self.shouldRegisterUsername = NO;
        [self.registerUsernameSwitch setOn:FALSE animated:NO];
    }

    self.indexLabel.text = [NSString stringWithFormat:@"%d", [self.wallet unusedBlockchainIdentityIndex]];
}

- (IBAction)registerUsernameSwitchValueChanged:(UISwitch *)sender {
    self.shouldRegisterUsername = sender.isOn;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setToDefaultWallet {
    self.wallet = nil;
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        for (DSAccount *account in wallet.accounts) {
            if (account.balance > 0) {
                self.wallet = wallet;
                break;
            }
        }
    }
}

- (void)setWallet:(DSWallet *)wallet {
    _wallet = wallet;
    self.walletIdentifierLabel.text = wallet.uniqueIDString;
}

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
    NSString *desiredUsername = [self.usernameLabel.text lowercaseString];
    if (desiredUsername.length < 4) {
        [self raiseIssue:@"Username too short" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
        return;
    } else if (desiredUsername.length > 23) {
        [self raiseIssue:@"Username too long" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
        return;
    } else if (!_wallet) {
        [self raiseIssue:@"No wallet with balance" message:@"To create a blockchain user you must have a wallet with enough balance to pay the minimum credit fee"];
        return;
    } else {
        NSCharacterSet *illegalChars = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        if ([desiredUsername rangeOfCharacterFromSet:illegalChars].location != NSNotFound) {
            [self raiseIssue:@"Username contains illegal characters" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
            return;
        }
    }
    NSString *invitationLink = self.invitationLinkLabel.text;

    DSBlockchainIdentityRegistrationStep steps = DSBlockchainIdentityRegistrationStep_LocalInWalletPersistence | DSBlockchainIdentityRegistrationStep_Identity;
    if (self.shouldRegisterUsername) {
        steps |= DSBlockchainIdentityRegistrationStep_Username;
    }

    uint32_t index = [self.indexLabel.text intValue];

    DSBlockchainInvitation *invitation = [[DSBlockchainInvitation alloc] initWithInvitationLink:invitationLink inWallet:self.wallet];

    [invitation acceptInvitationUsingWalletIndex:index
        setDashpayUsername:desiredUsername
        authenticationPrompt:@"Would you like to accept the invitation?"
        identityRegistrationSteps:steps
        stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {

        }
        completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *_Nonnull error) {
            if (error) {
                [self raiseIssue:@"Error" message:error.localizedDescription];
                return;
            } else {
                [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
            }
        }
        completionQueue:dispatch_get_main_queue()];
}

- (void)viewController:(UIViewController *)controller didChooseWallet:(DSWallet *)wallet {
    self.wallet = wallet;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainIdentityFromInvitationChooseWalletSegue"]) {
        DSWalletChooserViewController *chooseWalletSegue = (DSWalletChooserViewController *)segue.destinationViewController;
        chooseWalletSegue.chain = self.chainManager.chain;
        chooseWalletSegue.delegate = self;
    }
}


@end
