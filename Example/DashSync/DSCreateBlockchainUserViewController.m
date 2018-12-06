//
//  DSCreateBlockchainUserViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/27/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSCreateBlockchainUserViewController.h"
#import "DSWalletChooserViewController.h"
#import "DSAccountChooserViewController.h"
#import "DSBlockchainUserRegistrationTransaction.h"

@interface DSCreateBlockchainUserViewController ()
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
@property (strong, nonatomic) IBOutlet UITextField *usernameLabel;
@property (strong, nonatomic) IBOutlet UITextField *topupAmountLabel;
@property (strong, nonatomic) IBOutlet UILabel *walletIdentifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *fundingAccountIdentifierLabel;
@property (strong, nonatomic) DSWallet * wallet;
@property (strong, nonatomic) DSAccount * fundingAccount;

@end

@implementation DSCreateBlockchainUserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setToDefaultAccount];
    if (self.fundingAccount) {
        self.wallet = self.fundingAccount.wallet;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setToDefaultAccount {
    self.fundingAccount = nil;
    for (DSWallet * wallet in self.chainManager.chain.wallets) {
        for (DSAccount * account in wallet.accounts) {
            if (account.balance > 0) {
                self.fundingAccount = account;
                break;
            }
        }
        if (self.fundingAccount) break;
    }
}

-(void)setWallet:(DSWallet *)wallet {
    _wallet = wallet;
    self.walletIdentifierLabel.text = wallet.uniqueID;
}

-(void)setFundingAccount:(DSAccount *)fundingAccount {
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

-(void)raiseIssue:(NSString*)issue message:(NSString*)message {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:issue message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alert animated:TRUE completion:^{
        
    }];
}

- (IBAction)done:(id)sender {
    
    NSString * desiredUsername = [self.usernameLabel.text lowercaseString];
    NSScanner *scanner = [NSScanner scannerWithString:self.topupAmountLabel.text];
    uint64_t topupAmount = 0;
    [scanner scanUnsignedLongLong:&topupAmount];
    if (desiredUsername.length < 4) {
        [self raiseIssue:@"Username too short" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
        return;
    } else if (desiredUsername.length > 23) {
        [self raiseIssue:@"Username too long" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
        return;
    } else if (!_wallet) {
        [self raiseIssue:@"No wallet with balance" message:@"To create a blockchain user you must have a wallet with enough balance to pay the minimum credit fee"];
        return;
    } else if (!_fundingAccount) {
        [self raiseIssue:@"No funding account with balance" message:@"To create a blockchain user you must have a wallet with enough balance to pay the minimum credit fee"];
        return;
    } else {
        NSCharacterSet * illegalChars = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        if ([desiredUsername rangeOfCharacterFromSet:illegalChars].location != NSNotFound) {
            [self raiseIssue:@"Username contains illegal characters" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
            return;
        }
    }
    DSBlockchainUser * blockchainUser = [self.wallet createBlockchainUserForUsername:desiredUsername];
    [blockchainUser generateBlockchainUserExtendedPublicKey:^(BOOL exists) {
        if (exists) {
            [blockchainUser registrationTransactionForTopupAmount:topupAmount fundedByAccount:self.fundingAccount completion:^(DSBlockchainUserRegistrationTransaction *blockchainUserRegistrationTransaction) {
                if (blockchainUserRegistrationTransaction) {
                    [self.fundingAccount signTransaction:blockchainUserRegistrationTransaction withPrompt:@"Would you like to create this user?" completion:^(BOOL signedTransaction) {
                        if (signedTransaction) {
                            [self.chainManager.transactionManager publishTransaction:blockchainUserRegistrationTransaction completion:^(NSError * _Nullable error) {
                                if (error) {
                                    [self raiseIssue:@"Error" message:error.localizedDescription];
                                } else {
                                    [blockchainUser registerInWallet];
                                    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
                                }
                            }];
                        } else {
                            [self raiseIssue:@"Error" message:@"Transaction was not signed."];
                        }
                    }];
                } else {
                    [self raiseIssue:@"Error" message:@"Unable to create BlockchainUserRegistrationTransaction."];
                }
            }];
        } else {
            [self raiseIssue:@"Error" message:@"Unable to register blockchain user."];
        }
    }];
}

-(void)viewController:(UIViewController*)controller didChooseWallet:(DSWallet*)wallet {
    self.wallet = wallet;
}

-(void)viewController:(UIViewController*)controller didChooseAccount:(DSAccount *)account {
    self.fundingAccount = account;
}


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainUserChooseWalletSegue"]) {
        DSWalletChooserViewController * chooseWalletSegue = (DSWalletChooserViewController*)segue.destinationViewController;
        chooseWalletSegue.chain = self.chainManager.chain;
        chooseWalletSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"BlockchainUserChooseFundingAccountSegue"]) {
        DSAccountChooserViewController * chooseAccountSegue = (DSAccountChooserViewController*)segue.destinationViewController;
        chooseAccountSegue.chain = self.chainManager.chain;
        chooseAccountSegue.delegate = self;
    }
}




@end
