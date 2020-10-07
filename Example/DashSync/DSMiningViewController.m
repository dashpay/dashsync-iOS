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

#import "DSMiningViewController.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSFullBlock.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"
#import "BigIntTypes.h"

@interface DSMiningViewController ()
@property (strong, nonatomic) IBOutlet UISwitch *miningSwitch;
@property (strong, nonatomic) IBOutlet UILabel *hashRateLabel;

@end

@implementation DSMiningViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
- (IBAction)miningSwitchDidChangeValue:(id)sender {
    if (_miningSwitch.on) {
        [self mineBlocks];
    } else {
        [self stopMining];
    }
}

-(void)mineBlocks {
    if (_miningSwitch.on && self.chainManager.chain.wallets.count) {
        DSWallet * wallet = self.chainManager.chain.wallets[0];
        DSAccount * account = wallet.accounts[0];
        [self.chainManager mineEmptyBlocks:1 toPaymentAddress:account.receiveAddress withTimeout:100000 completion:^(NSArray<DSFullBlock *> * _Nonnull blocks, NSArray<NSNumber *> * _Nonnull attempts, NSTimeInterval timeUsed, NSError * _Nullable error) {
            BOOL addingBlockIssue = NO;
            for (DSFullBlock * block in blocks) {
                for (DSTransaction * transaction in block.transactions) {
                    [self.chainManager.transactionManager peer:nil relayedTransaction:transaction inBlock:block];
                }
                addingBlockIssue |= ![self.chainManager.chain addMinedFullBlock:block];
            }
            if (!addingBlockIssue) {
                [self mineBlocks];
            }
        }];
    }
}

-(void)stopMining {
    
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
