//
//  DSProposalCreatorViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 7/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSProposalCreatorViewController.h"
#import <DashSync/DashSync.h>

@interface DSProposalCreatorViewController ()
@property (strong, nonatomic) IBOutlet UIBarButtonItem *saveButton;
- (IBAction)save:(id)sender;
- (IBAction)cancel:(id)sender;
@property (strong, nonatomic) IBOutlet UITextField *identifierTextField;
@property (strong, nonatomic) IBOutlet UITextField *amountTextField;
@property (strong, nonatomic) IBOutlet UILabel *accountInfoLabel;
@property (strong, nonatomic) IBOutlet UITextField *addressTextField;
@property (strong, nonatomic) IBOutlet UITextField *startTextField;
@property (strong, nonatomic) IBOutlet UITextField *cyclesTextField;
@property (strong, nonatomic) IBOutlet UITextField *urlTextField;
@property (strong, nonatomic) DSAccount *account;

@end

@implementation DSProposalCreatorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.saveButton.enabled = FALSE;
    [self setToDefaultAccount];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)validAmountForString:(NSString *)string {
    uint64_t amount = [[DSPriceManager sharedInstance] amountForDashString:string];
    return (amount > 0);
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *novelString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == self.identifierTextField) {
        if ([self validAmountForString:self.amountTextField.text] && ![novelString isEqualToString:@""]) {
            self.saveButton.enabled = TRUE;
        } else {
            self.saveButton.enabled = FALSE;
        }
    } else if (textField == self.amountTextField) {
        if ([self validAmountForString:novelString] && ![self.identifierTextField.text isEqualToString:@""]) {
            self.saveButton.enabled = TRUE;
        } else {
            self.saveButton.enabled = FALSE;
        }
    }

    return TRUE;
}

// MARK:- Account Choosing

- (void)setToDefaultAccount {
    self.account = nil;
    for (DSWallet *wallet in self.chainManager.chain.wallets) {
        for (DSAccount *account in wallet.accounts) {
            if (account.balance > PROPOSAL_COST) {
                self.account = account;
                break;
            }
        }
        if (self.account) break;
    }
    if (self.account) {
        self.accountInfoLabel.text = [NSString stringWithFormat:@"%@-%u", self.account.wallet.uniqueIDString, self.account.accountNumber];
        self.addressTextField.placeholder = self.account.defaultDerivationPath.receiveAddress;
    }
}

- (void)viewController:(UIViewController *)controller didChooseAccount:(DSAccount *)account {
    self.account = account;
    self.accountInfoLabel.text = [NSString stringWithFormat:@"%@-%u", self.account.wallet.uniqueIDString, self.account.accountNumber];
    self.addressTextField.placeholder = self.account.defaultDerivationPath.receiveAddress;
}

- (NSString *)currentAddress {
    if ([self.addressTextField.text isValidDashAddressOnChain:self.chainManager.chain]) {
        return self.addressTextField.text;
    } else {
        return self.account.defaultDerivationPath.receiveAddress;
    }
}

#pragma mark - Table view data source


- (IBAction)save:(id)sender;
{
    NSString *identifier = self.identifierTextField.text;
    uint64_t amount = [[DSPriceManager sharedInstance] amountForDashString:self.amountTextField.text];
    DSGovernanceSyncManager *governanceManager = self.chainManager.governanceSyncManager;
    NSString *address = [self currentAddress];

    __block DSGovernanceObject *proposal = [governanceManager createProposalWithIdentifier:identifier toPaymentAddress:address forAmount:amount fromAccount:self.account startDate:[NSDate date] cycles:1 url:@"dash.org"];
    __block DSTransaction *transaction = [proposal collateralTransactionForAccount:self.account];
    [self.account signTransaction:transaction
                       withPrompt:@""
                       completion:^(BOOL signedTransaction, BOOL cancelled) {
                           if (signedTransaction) {
                               [self.chainManager.transactionManager publishTransaction:transaction
                                                                             completion:^(NSError *_Nullable error) {
                                                                                 if (error) {
                                                                                     NSLog(@"%@", error);
                                                                                 } else {
                                                                                     [self.account registerTransaction:transaction saveImmediately:YES];
                                                                                     [proposal registerCollateralTransaction:transaction];
                                                                                     [proposal save];
                                                                                     [self.chainManager.governanceSyncManager publishProposal:proposal];
                                                                                     [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
                                                                                 }
                                                                             }];
                           }
                       }];
}

- (IBAction)cancel:(id)sender;
{
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseAccountSegue"]) {
        DSAccountChooserViewController *chooseAccountSegue = (DSAccountChooserViewController *)segue.destinationViewController;
        chooseAccountSegue.chain = self.chainManager.chain;
        chooseAccountSegue.minAccountBalanceNeeded = PROPOSAL_COST;
        chooseAccountSegue.delegate = self;
    }
}

@end
