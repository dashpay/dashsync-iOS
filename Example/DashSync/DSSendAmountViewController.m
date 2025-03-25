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

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *novelString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == self.addressField) {
        self.isValidAddress = DIsValidDashAddress(DChar(novelString), self.account.wallet.chain.chainType);
    } else if (textField == self.amountField) {
        self.isValidAmount = [[DSPriceManager sharedInstance] amountForDashString:novelString] > 0;
    }
    self.sendButton.enabled = [self isValidAmount] && [self isValidAddress];
    return TRUE;
}

- (IBAction)send:(id)sender {
    DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:self.addressField.text onChain:self.account.wallet.chain];
    paymentRequest.amount = [[DSPriceManager sharedInstance] amountForDashString:self.amountField.text];

    if ([paymentRequest isValidAsNonDashpayPaymentRequest]) {
        __block BOOL displayedSentMessage = FALSE;

        [self.account.wallet.chain.chainManager.transactionManager confirmPaymentRequest:paymentRequest
            usingUserIdentity:nil
            fromAccount:self.account
            acceptInternalAddress:YES
            acceptReusingAddress:YES
            addressIsFromPasteboard:NO
            requiresSpendingAuthenticationPrompt:NO
            keepAuthenticatedIfErrorAfterAuthentication:NO
            requestingAdditionalInfo:^(DSRequestingAdditionalInfo additionalInfoRequestType) {
            }
            presentChallenge:^(NSString *_Nonnull challengeTitle, NSString *_Nonnull challengeMessage, NSString *_Nonnull actionTitle, void (^_Nonnull actionBlock)(void), void (^_Nonnull cancelBlock)(void)) {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:challengeTitle
                                     message:challengeMessage
                              preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *ignoreButton = [UIAlertAction
                    actionWithTitle:actionTitle
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                                actionBlock();
                            }];
                UIAlertAction *cancelButton = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"cancel", nil)
                              style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction *action) {
                                cancelBlock();
                            }];

                [alert addAction:cancelButton]; //cancel should always be on the left
                [alert addAction:ignoreButton];
                [self presentViewController:alert animated:YES completion:nil];
            }
            transactionCreationCompletion:^BOOL(DSTransaction *tx, NSString *prompt, uint64_t amount, uint64_t proposedFee, NSArray<NSString *> *addresses, BOOL isSecure) {
                return TRUE; //just continue and let Dash Sync do it's thing
            }
            signedCompletion:^BOOL(DSTransaction *_Nonnull tx, NSError *_Nullable error, BOOL cancelled) {
                if (cancelled) {
                } else if (error) {
                    UIAlertController *alert = [UIAlertController
                        alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                         message:error.localizedDescription
                                  preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okButton = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"ok", nil)
                                  style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action){

                                }];
                    [alert addAction:okButton];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                return TRUE;
            }
            publishedCompletion:^(DSTransaction *_Nonnull tx, NSError *_Nullable error, BOOL sent) {
                if (sent) {
                    [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                                center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                              popOutAfterDelay:2.0]];


                    displayedSentMessage = TRUE;
                }
            }
            errorNotificationBlock:^(NSError *_Nonnull error, NSString *_Nullable errorTitle, NSString *_Nullable errorMessage, BOOL shouldCancel) {
                if (errorTitle || errorMessage) {
                    UIAlertController *alert = [UIAlertController
                        alertControllerWithTitle:errorTitle
                                         message:errorMessage
                                  preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okButton = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"ok", nil)
                                  style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action){
                                }];
                    [alert addAction:okButton];
                    [self presentViewController:alert animated:YES completion:nil];
                }
            }];
    } else {
        [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
    }
}

- (IBAction)cancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
