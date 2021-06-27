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

#import "DSDAPIGetTransactionInformationViewController.h"
#import "BRBubbleView.h"
#import "DSTransactionDetailViewController.h"

@interface DSDAPIGetTransactionInformationViewController ()

@property (strong, nonatomic) IBOutlet UITextField *transactionHashTextField;
@property (strong, nonatomic) DSTransaction *currentTranasction;
- (IBAction)retrieveTransaction:(id)sender;

@end

@implementation DSDAPIGetTransactionInformationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)retrieveTransaction:(id)sender {
    UInt256 transactionHash = [self.transactionHashTextField.text hexToData].UInt256;
    if (uint256_is_zero(transactionHash)) {
        [self.view addSubview:[[[BRBubbleView viewWithText:[NSString stringWithFormat:@"%@", @"invalid transaction hash"]
                                                    center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                  popOutAfterDelay:2.0]];
        return;
    }
    [self.chainManager.DAPIClient.DAPICoreNetworkService getTransactionWithHash:transactionHash
        completionQueue:dispatch_get_main_queue()
        success:^(DSTransaction *_Nonnull transaction) {
            self.currentTranasction = transaction;
            [self performSegueWithIdentifier:@"GetTransactionInfoDetailsSegue" sender:self];
        }
        failure:^(NSError *_Nonnull error) {
            if (error.code == 404) {
                //try searching for reverse
                [self.chainManager.DAPIClient.DAPICoreNetworkService getTransactionWithHash:uint256_reverse(transactionHash)
                    completionQueue:dispatch_get_main_queue()
                    success:^(DSTransaction *_Nonnull transaction) {
                        self.currentTranasction = transaction;
                        [self performSegueWithIdentifier:@"GetTransactionInfoDetailsSegue" sender:self];
                    }
                    failure:^(NSError *_Nonnull error) {
                        [self.view addSubview:[[[BRBubbleView viewWithText:[NSString stringWithFormat:@"%@", error.localizedDescription]
                                                                    center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                                  popOutAfterDelay:2.0]];
                    }];
            } else {
                [self.view addSubview:[[[BRBubbleView viewWithText:[NSString stringWithFormat:@"%@", error.localizedDescription]
                                                            center:CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2)] popIn]
                                          popOutAfterDelay:2.0]];
            }
        }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"GetTransactionInfoDetailsSegue"]) {
        DSTransactionDetailViewController *transactionDetailViewController = (DSTransactionDetailViewController *)segue.destinationViewController;
        transactionDetailViewController.transaction = self.currentTranasction;
    }
}

@end
