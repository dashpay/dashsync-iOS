//
//  DSCreateBlockchainUserViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/27/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSCreateBlockchainUserViewController.h"
#import "DSWalletChooserViewController.h"

@interface DSCreateBlockchainUserViewController ()
- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;
@property (strong, nonatomic) IBOutlet UITextField *usernameLabel;
@property (strong, nonatomic) IBOutlet UILabel *walletIdentifierLabel;
@property (strong, nonatomic) DSWallet * wallet;

@end

@implementation DSCreateBlockchainUserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setToDefaultWallet];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setToDefaultWallet {
    self.wallet = nil;
    for (DSWallet * wallet in self.chain.wallets) {
        if (wallet.balance != 0) {
            self.wallet = wallet;
            break;
        }
    }
}

-(void)setWallet:(DSWallet *)wallet {
    _wallet = wallet;
    self.walletIdentifierLabel.text = wallet.uniqueID;
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
}

- (IBAction)done:(id)sender {
    
    NSString * desiredUsername = self.usernameLabel.text;
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
        NSCharacterSet * illegalChars = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        if ([desiredUsername rangeOfCharacterFromSet:illegalChars].location != NSNotFound) {
            [self raiseIssue:@"Username contains illegal characters" message:@"Your blockchain username must be between 4 and 23 characters long and contain only alphanumeric characters. Underscores are also permitted."];
            return;
        }
    }
    DSBlockchainUser * blockchainUser = [self.wallet createBlockchainUserForUsername:desiredUsername];
    [self.wallet registerBlockchainUser:blockchainUser];
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

-(void)viewController:(UIViewController*)controller didChooseWallet:(DSWallet*)wallet {
    self.wallet = wallet;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"BlockchainUserChooseWalletSegue"]) {
        DSWalletChooserViewController * chooseWalletSegue = (DSWalletChooserViewController*)segue.destinationViewController;
        chooseWalletSegue.chain = self.chain;
        chooseWalletSegue.delegate = self;
    }
}




@end
