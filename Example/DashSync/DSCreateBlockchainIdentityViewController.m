//
//  DSCreateBlockchainIdentityViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/27/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSCreateBlockchainIdentityViewController.h"
#import "DSWalletChooserViewController.h"
#import "DSAccountChooserViewController.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSCreditFundingTransaction.h"

@interface DSCreateBlockchainIdentityViewController ()
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
@property (strong, nonatomic) IBOutlet UITextField *usernameLabel;
@property (strong, nonatomic) IBOutlet UITextField *topupAmountLabel;
@property (strong, nonatomic) IBOutlet UITextField *indexLabel;
@property (strong, nonatomic) IBOutlet UILabel *walletIdentifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *fundingAccountIdentifierLabel;
@property (strong, nonatomic) IBOutlet UILabel *typeLabel;
@property (strong, nonatomic) IBOutlet UISwitch *registerOnL2Switch;
@property (strong, nonatomic) IBOutlet UISwitch *registerUsernameSwitch;
@property (assign, nonatomic) DSBlockchainIdentityType identityType;
@property (strong, nonatomic) DSWallet * wallet;
@property (strong, nonatomic) DSAccount * fundingAccount;
@property (assign, nonatomic) BOOL shouldRegisterOnL2;
@property (assign, nonatomic) BOOL shouldRegisterUsername;


@end

@implementation DSCreateBlockchainIdentityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setToDefaultAccount];
    
    if (self.fundingAccount) {
        self.wallet = self.fundingAccount.wallet;
    }
    
    self.shouldRegisterOnL2 = YES;
    self.shouldRegisterUsername = YES;
    if (uint256_is_zero(self.wallet.chain.dpnsContractID)) {
        self.shouldRegisterUsername = NO;
        [self.registerUsernameSwitch setOn:FALSE animated:NO];
    }
    
    self.indexLabel.text = [NSString stringWithFormat:@"%d",[self.wallet unusedBlockchainIdentityIndex]];
    
    self.topupAmountLabel.text = [NSString stringWithFormat:@"%d",10000000]; //0.1 Dash
    
    self.identityType = DSBlockchainIdentityType_User;
}

-(IBAction)registerOnL2SwitchValueChanged:(UISwitch*)sender {
    
    self.shouldRegisterOnL2 = sender.isOn;
    if (!self.shouldRegisterOnL2) {
        [self.registerUsernameSwitch setOn:FALSE animated:YES];
        self.shouldRegisterUsername = NO;
    }
}

-(IBAction)registerUsernameSwitchValueChanged:(UISwitch*)sender {
    self.shouldRegisterUsername = sender.isOn;
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
    DSBlockchainIdentity * blockchainIdentity = [self.wallet createBlockchainIdentityOfType:self.identityType forUsername:desiredUsername usingDerivationIndex:[self.indexLabel.text intValue]];
    DSBlockchainIdentityRegistrationStep steps = DSBlockchainIdentityRegistrationStep_L1Steps;
    if (self.shouldRegisterOnL2) {
        steps |= DSBlockchainIdentityRegistrationStep_Identity;
    }
    if (self.shouldRegisterUsername) {
        steps |= DSBlockchainIdentityRegistrationStep_Username;
    }
    [blockchainIdentity registerOnNetwork:steps withFundingAccount:self.fundingAccount forTopupAmount:topupAmount stepCompletion:^(DSBlockchainIdentityRegistrationStep stepCompleted) {
        
    } completion:^(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError * _Nonnull error) {
        if (error) {
            [self raiseIssue:@"Error" message:error.localizedDescription];
            return;
        } else {
            [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
        }
    }];
}

-(void)viewController:(UIViewController*)controller didChooseWallet:(DSWallet*)wallet {
    self.wallet = wallet;
}

-(void)viewController:(UIViewController*)controller didChooseAccount:(DSAccount *)account {
    self.fundingAccount = account;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 5) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Identity Type"
                                                                                 message:nil
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"User"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *_Nonnull action) {
            self.typeLabel.text = @"User";
            self.identityType = DSBlockchainIdentityType_User;
                                                              }]];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"Application"
          style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *_Nonnull action) {
            self.typeLabel.text = @"Application";
            self.identityType = DSBlockchainIdentityType_Application;
        }]];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
}


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainIdentityChooseWalletSegue"]) {
        DSWalletChooserViewController * chooseWalletSegue = (DSWalletChooserViewController*)segue.destinationViewController;
        chooseWalletSegue.chain = self.chainManager.chain;
        chooseWalletSegue.delegate = self;
    } else if ([segue.identifier isEqualToString:@"BlockchainIdentityChooseAccountSegue"]) {
        DSAccountChooserViewController * chooseAccountSegue = (DSAccountChooserViewController*)segue.destinationViewController;
        chooseAccountSegue.chain = self.chainManager.chain;
        chooseAccountSegue.delegate = self;
    }
}




@end
