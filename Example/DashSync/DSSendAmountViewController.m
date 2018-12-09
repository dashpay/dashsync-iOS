//
//  DSSendAmountViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 6/23/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSSendAmountViewController.h"
#import "BRBubbleView.h"

@interface DSSendAmountViewController ()
- (IBAction)cancel:(id)sender;
- (IBAction)send:(id)sender;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (strong, nonatomic) IBOutlet UITextField *addressField;
@property (strong, nonatomic) IBOutlet UISwitch *instantSendSwitch;
@property (strong, nonatomic) IBOutlet UITextField *amountField;
@property (assign, nonatomic) BOOL isValidAddress;
@property (assign, nonatomic) BOOL isValidAmount;

@end

@implementation DSSendAmountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.sendButton.enabled = FALSE;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// MARK:- Text Field Delegate

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString * novelString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == self.addressField) {
        
        if ([novelString isValidDashAddressOnChain:self.account.wallet.chain]) {
            self.isValidAddress = TRUE;
        } else {
            self.isValidAddress = FALSE;
        }
    } else if (textField == self.amountField) {
        if ([[DSPriceManager sharedInstance] amountForDashString:novelString] > 0) {
            self.isValidAmount = TRUE;
        } else {
            self.isValidAmount = FALSE;
        }
    }
    if ([self isValidAmount] && [self isValidAddress]) {
        self.sendButton.enabled = TRUE;
    } else {
        self.sendButton.enabled = FALSE;
    }
    return TRUE;
}

-(IBAction)send:(id)sender {
    
    DSPaymentRequest * paymentRequest = [DSPaymentRequest requestWithString:self.addressField.text onChain:self.account.wallet.chain];
    paymentRequest.amount = [[DSPriceManager sharedInstance] amountForDashString:self.amountField.text];
    if ([paymentRequest isValid]) {
        [self.account.wallet.chain.chainManager.transactionManager confirmPaymentRequest:paymentRequest fromAccount:self.account forceInstantSend:self.instantSendSwitch.on signedCompletion:^(NSError * _Nonnull error) {
            if (!error) {
                if (self.navigationController.topViewController != self.parentViewController.parentViewController) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }
            }
        } publishedCompletion:^(NSError * _Nonnull error) {
            if (error) {

                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                             message:error.localizedDescription
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               
                                           }];
                [alert addAction:okButton];
                [self.navigationController.topViewController presentViewController:alert animated:YES completion:nil];
                [self cancel:nil];
            } else {
                [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                                                       center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                                                  popOutAfterDelay:2.0]];
            }
        }];
    } else {
        [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
    }
}

-(IBAction)cancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
