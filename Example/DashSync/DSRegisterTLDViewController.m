//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSRegisterTLDViewController.h"
#import <DashSync/DashSync.h>

@interface DSRegisterTLDViewController ()
@property (strong, nonatomic) IBOutlet UITextField *topLevelDomainTextField;

@end

@implementation DSRegisterTLDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)registerTLD:(id)sender {
    DSChain * chain = self.blockchainIdentity.wallet.chain;
    DPContract * dpnsContract = [DSDashPlatform sharedInstanceForChain:chain].dpnsContract;
    DSBlockchainIdentity * dpnsBlockchainIdentity = [chain blockchainIdentityThatCreatedContract:dpnsContract withContractId:chain.dpnsContractID foundInWallet:nil];
    if (self.blockchainIdentity == dpnsBlockchainIdentity) {
        [self.blockchainIdentity addUsername:self.topLevelDomainTextField.text inDomain:@"" save:YES];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
