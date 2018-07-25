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

-(void)insufficientFundsForTransaction:(DSTransaction *)tx forAmount:(uint64_t)requestedSendAmount localCurrency:(NSString *)localCurrency localCurrencyAmount:(NSString *)localCurrencyAmount {
    DSPriceManager * manager = [DSPriceManager sharedInstance];
    uint64_t fuzz = [manager amountForLocalCurrencyString:[manager localCurrencyStringForDashAmount:1]]*2;
    
    // if user selected an amount equal to or below wallet balance, but the fee will bring the total above the
    // balance, offer to reduce the amount to available funds minus fee
    if (requestedSendAmount <= self.account.balance + fuzz && requestedSendAmount > 0) {
        int64_t amount = [self.account maxOutputAmountUsingInstantSend:tx.isInstant];
        
        if (amount > 0 && amount < requestedSendAmount) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"insufficient funds for dash network fee", nil)
                                         message:[NSString stringWithFormat:NSLocalizedString(@"reduce payment amount by\n%@ (%@)?", nil),
                                                  [manager stringForDashAmount:requestedSendAmount - amount],
                                                  [manager localCurrencyStringForDashAmount:requestedSendAmount - amount]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* cancelButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"cancel", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {

                                           }];
            UIAlertAction* reduceButton = [UIAlertAction
                                           actionWithTitle:[NSString stringWithFormat:@"%@ (%@)",
                                                            [manager stringForDashAmount:amount - requestedSendAmount],
                                                            [manager localCurrencyStringForDashAmount:amount - requestedSendAmount]]
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * action) {
//                                               [self confirmProtocolRequest:self.request currency:self.scheme associatedShapeshift:self.associatedShapeshift localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                                           }];
            
            
            [alert addAction:cancelButton];
            [alert addAction:reduceButton];
            [self presentViewController:alert animated:YES completion:nil];
            requestedSendAmount = amount;
        }
        else {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"insufficient funds for dash network fee", nil)
                                         message:nil
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                           
                                       }];
            
            
            [alert addAction:okButton];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
    else {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:NSLocalizedString(@"insufficient funds", nil)
                                     message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"ok", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       
                                   }];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)confirmTransaction:(DSTransaction *)tx toAddress:(NSString*)address withPrompt:(NSString *)prompt forAmount:(uint64_t)amount localCurrency:(NSString *)localCurrency localCurrencyAmount:(NSString *)localCurrencyAmount
{
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    __block BOOL previouslyWasAuthenticated = authenticationManager.didAuthenticate;
    
    if (! tx) { // tx is nil if there were insufficient wallet funds
        if (authenticationManager.didAuthenticate) {
            [self insufficientFundsForTransaction:tx forAmount:amount localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
        } else {
            [authenticationManager seedWithPrompt:prompt forWallet:self.account.wallet forAmount:amount completion:^(NSData * _Nullable seed) {
                if (seed) {
                    [self insufficientFundsForTransaction:tx forAmount:amount localCurrency:localCurrency localCurrencyAmount:localCurrencyAmount];
                } else {

                }
                if (!previouslyWasAuthenticated) authenticationManager.didAuthenticate = NO;
            }];
        }
    } else {
        
        [self.account signTransaction:tx withPrompt:prompt completion:^(BOOL signedTransaction) {
            if (!signedTransaction) {
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:NSLocalizedString(@"couldn't make payment", nil)
                                             message:NSLocalizedString(@"error signing dash transaction", nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                               
                                           }];
                [alert addAction:okButton];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                
                if (! previouslyWasAuthenticated) authenticationManager.didAuthenticate = NO;
                
                if (! tx.isSigned) { // double check
                    return;
                }
                
                if (self.navigationController.topViewController != self.parentViewController.parentViewController) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }
                
                __block BOOL waiting = YES, sent = NO;
                
                [[[DSChainManager sharedInstance] peerManagerForChain:self.account.wallet.chain] publishTransaction:tx completion:^(NSError *error) {
                    if (error) {
                        if (! waiting && ! sent) {
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
                            [self presentViewController:alert animated:YES completion:nil];
                            [self cancel:nil];
                        }
                    }
                    else if (! sent) { //TODO: show full screen sent dialog with tx info, "you sent b10,000 to bob"
                        sent = YES;
                        tx.timestamp = [NSDate timeIntervalSinceReferenceDate];
                        [self.account registerTransaction:tx];
                        [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                                    center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                               popOutAfterDelay:2.0]];
                        
                    }
                    
                    waiting = NO;
                }];
            }
        }];
    }
}


-(IBAction)send:(id)sender {
    
    DSPaymentRequest * paymentRequest = [DSPaymentRequest requestWithString:self.addressField.text onChain:self.account.wallet.chain];
    paymentRequest.amount = [[DSPriceManager sharedInstance] amountForDashString:self.amountField.text];
    if ([paymentRequest isValid]) {
        DSPaymentProtocolRequest * protocolRequest = paymentRequest.protocolRequest;
        DSTransaction * transaction = [self.account transactionForAmounts:protocolRequest.details.outputAmounts toOutputScripts:protocolRequest.details.outputScripts withFee:TRUE isInstant:self.instantSendSwitch.on];
        if (transaction) {
        uint64_t fee = [self.account feeForTransaction:transaction];
        NSString *prompt = [[DSAuthenticationManager sharedInstance] promptForAmount:paymentRequest.amount
                                             fee:fee
                                         address:self.addressField.text
                                            name:protocolRequest.commonName
                                            memo:protocolRequest.details.memo
                                        isSecure:TRUE//(valid && ! [protoReq.pkiType isEqual:@"none"])
                                                                        errorMessage:nil
                                   localCurrency:nil
                             localCurrencyAmount:nil];
        CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
            [self confirmTransaction:transaction toAddress:self.addressField.text withPrompt:prompt forAmount:paymentRequest.amount localCurrency:nil localCurrencyAmount:nil];
        });
        }
    } else {
        [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
    }
}

-(IBAction)cancel:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:TRUE completion:nil];
}

@end
