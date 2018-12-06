//
//  DSTransactionFloodingViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 12/6/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSTransactionFloodingViewController.h"
#import "DSAccountChooserViewController.h"
#import "BRBubbleView.h"

@interface DSTransactionFloodingViewController ()

@property (nonatomic,assign) NSUInteger alreadySentCount;
@property (nonatomic,assign) BOOL choosingDestinationAccount;
@property (nonatomic, strong) DSAccount * fundingAccount;
@property (nonatomic, strong) DSAccount * destinationAccount;


@property (nonatomic, strong) IBOutlet UILabel * fundingAccountIdentifierLabel;
@property (nonatomic, strong) IBOutlet UILabel * destinationAccountIdentifierLabel;

@property (nonatomic, strong) IBOutlet UITextField * transactionCountTextField;

@property (nonatomic, strong) IBOutlet UIBarButtonItem * startFloodingButton;

@end

@implementation DSTransactionFloodingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.alreadySentCount = 0;
    self.startFloodingButton.enabled = FALSE;
}

-(void)insufficientFundsForTransaction:(DSTransaction *)tx forAmount:(uint64_t)requestedSendAmount {
    DSPriceManager * manager = [DSPriceManager sharedInstance];
    uint64_t fuzz = [manager amountForLocalCurrencyString:[manager localCurrencyStringForDashAmount:1]]*2;
    
    // if user selected an amount equal to or below wallet balance, but the fee will bring the total above the
    // balance, offer to reduce the amount to available funds minus fee
    if (requestedSendAmount <= self.fundingAccount.balance + fuzz && requestedSendAmount > 0) {
        int64_t amount = [self.fundingAccount maxOutputAmountUsingInstantSend:tx.isInstant];
        
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


- (void)confirmTransaction:(DSTransaction *)tx toAddress:(NSString*)address forAmount:(uint64_t)amount
{
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    __block BOOL previouslyWasAuthenticated = authenticationManager.didAuthenticate;
    
    if (! tx) { // tx is nil if there were insufficient wallet funds
        if (authenticationManager.didAuthenticate) {
            [self insufficientFundsForTransaction:tx forAmount:amount];
        } else {
            [authenticationManager seedWithPrompt:@"seed" forWallet:self.fundingAccount.wallet forAmount:amount forceAuthentication:NO completion:^(NSData * _Nullable seed) {
                if (seed) {
                    [self insufficientFundsForTransaction:tx forAmount:amount];
                } else {
                    
                }
                if (!previouslyWasAuthenticated) [authenticationManager deauthenticate];
            }];
        }
    } else {
        
        [self.fundingAccount signTransaction:tx withPrompt:nil completion:^(BOOL signedTransaction) {
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
                
                if (! tx.isSigned) { // double check
                    return;
                }
                
                __block BOOL waiting = YES, sent = NO;
                
                [self.chainManager.transactionManager publishTransaction:tx completion:^(NSError *error) {
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
                        }
                    }
                    else if (! sent) { //TODO: show full screen sent dialog with tx info, "you sent b10,000 to bob"
                        sent = YES;
                        tx.timestamp = [NSDate timeIntervalSince1970];
                        [self.fundingAccount registerTransaction:tx];
                        [self.view addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"sent!", nil)
                                                                    center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)] popIn]
                                               popOutAfterDelay:2.0]];
                        self.transactionCountTextField.text = [NSString stringWithFormat:@"%ld",[self.transactionCountTextField.text integerValue] - 1];
                        [self send:nil];
                        
                    }
                    
                    waiting = NO;
                }];
            }
        }];
    }
}

-(void)send:(id)sender {
    if ([self.transactionCountTextField.text integerValue] > 0) {
        DSPaymentRequest * paymentRequest = [DSPaymentRequest requestWithString:[self.destinationAccount.bip44DerivationPath receiveAddressAtOffset:self.alreadySentCount] onChain:self.chainManager.chain];
        paymentRequest.amount = 1000;
        DSPaymentProtocolRequest * protocolRequest = paymentRequest.protocolRequest;
        DSTransaction * transaction = [self.fundingAccount transactionForAmounts:protocolRequest.details.outputAmounts toOutputScripts:protocolRequest.details.outputScripts withFee:TRUE isInstant:NO];
        if (transaction) {
            CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
                [self confirmTransaction:transaction toAddress:self.destinationAccount.receiveAddress forAmount:paymentRequest.amount];
            });
        }
    } else {
        self.alreadySentCount = 0;
    }
}

-(IBAction)startFlooding:(id)sender {
    [self send:self];
}

-(BOOL)readyToStart {
    if (!self.fundingAccount) return NO;
    if (!self.destinationAccount) return NO;
    if (![self.transactionCountTextField.text integerValue] || [self.transactionCountTextField.text integerValue] > 1000) return NO;
    return YES;
}

-(void)updateStartButton {
    self.startFloodingButton.enabled = [self readyToStart];
}

-(void)setFundingAccount:(DSAccount *)fundingAccount {
    _fundingAccount = fundingAccount;
    self.fundingAccountIdentifierLabel.text = fundingAccount.uniqueID;
    [self updateStartButton];
}

-(void)setDestinationAccount:(DSAccount *)destinationAccount {
    _destinationAccount = destinationAccount;
    self.destinationAccountIdentifierLabel.text = destinationAccount.uniqueID;
    [self updateStartButton];
}

-(void)viewController:(UIViewController*)controller didChooseAccount:(DSAccount*)account {
    if (self.choosingDestinationAccount) {
        self.destinationAccount = account;
    } else {
        self.fundingAccount = account;
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ChooseFundingAccountSegue"] || [segue.identifier isEqualToString:@"ChooseDestinationAccountSegue"]) {
        DSAccountChooserViewController * chooseAccountSegue = (DSAccountChooserViewController*)segue.destinationViewController;
        chooseAccountSegue.chain = self.chainManager.chain;
        chooseAccountSegue.delegate = self;
        if ([segue.identifier isEqualToString:@"ChooseDestinationAccountSegue"]) {
            self.choosingDestinationAccount = TRUE;
        } else {
            self.choosingDestinationAccount = FALSE;
        }
    }
}

@end
