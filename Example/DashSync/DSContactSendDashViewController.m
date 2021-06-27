//
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSContactSendDashViewController.h"
#import "BRBubbleView.h"
#import "DSIncomingFundsDerivationPath.h"

@interface DSContactSendDashViewController ()
@property (strong, nonatomic) IBOutlet UITextField *addressTextField;
@property (strong, nonatomic) IBOutlet UITextField *amountTextField;
@property (strong, nonatomic) DSAccount *account;
@property (strong, nonatomic) NSString *address;
@property (strong, nonatomic) DSFriendRequestEntity *friendRequest;

@end

@implementation DSContactSendDashViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    DSFriendRequestEntity *friendRequest = [[_contact.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact.associatedBlockchainIdentity.uniqueID == %@", self.blockchainIdentity.uniqueIDData]] anyObject];
    NSAssert(friendRequest, @"there must be a friendRequest");
    self.friendRequest = friendRequest;
    self.account = [self.blockchainIdentity.wallet accountWithNumber:0];
    [self reloadAddressField];
}

- (void)reloadAddressField {
    DSIncomingFundsDerivationPath *derivationPath = [self.account derivationPathForFriendshipWithIdentifier:self.friendRequest.friendshipIdentifier];
    NSAssert(derivationPath.extendedPublicKeyData, @"Extended public key must exist already");
    self.address = [derivationPath receiveAddress];
    NSIndexPath *indexPath = [derivationPath indexPathForKnownAddress:self.address];
    self.addressTextField.text = [NSString stringWithFormat:@"%lu - %@", (unsigned long)[indexPath indexAtPosition:0], self.address];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)sendTransaction:(id)sender {
    DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:self.address onChain:self.account.wallet.chain];
    paymentRequest.amount = [[DSPriceManager sharedInstance] amountForDashString:self.amountTextField.text];

    if ([paymentRequest isValidAsNonDashpayPaymentRequest]) {
        __block BOOL displayedSentMessage = FALSE;

        [self.account.wallet.chain.chainManager.transactionManager confirmPaymentRequest:paymentRequest
            usingUserBlockchainIdentity:nil
            fromAccount:self.account
            acceptInternalAddress:NO
            acceptReusingAddress:YES
            addressIsFromPasteboard:NO
            requiresSpendingAuthenticationPrompt:YES
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
            transactionCreationCompletion:^BOOL(DSTransaction *_Nonnull tx, NSString *_Nonnull prompt, uint64_t amount, uint64_t proposedFee, NSArray<NSString *> *_Nonnull addresses, BOOL isSecure) {
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
                    [self reloadAddressField];
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

@end
