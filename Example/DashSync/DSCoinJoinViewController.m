//
//  Created by Andrei Ashikhmin
//  Copyright © 2023 Dash Core Group. All rights reserved.
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

#import "DSCoinJoinViewController.h"
#import "DSChainManager.h"
#import "NSString+Dash.h"
#import "DSCoinJoinManager.h"

@implementation DSCoinJoinViewController

- (IBAction)coinJoinSwitchDidChangeValue:(id)sender {
    if (_coinJoinSwitch.on) {
        [self startCoinJoin];
    } else {
        [self stopCoinJoin];
    }
}

- (void)stopCoinJoin {
    // TODO
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
//    unregister_coinjoin(_coinJoin);
//    _coinJoin = NULL;
}

- (void)startCoinJoin {
    // TODO: subscribe
    // TODO: refreshUnusedKeys()
    
    if (_coinJoinManager == NULL) {
        _coinJoinManager = [DSCoinJoinManager sharedInstanceForChain:_chainManager.chain];
    }
    
    [_coinJoinManager start];
//    wallet.getCoinJoin().refreshUnusedKeys(); TODO
    [_coinJoinManager setStopOnNothingToDo:true];
    
    if (![_coinJoinManager startMixing]) {
        DSLog(@"[OBJ-C] CoinJoin: Mixing has been started already.");
    }
    
    [_coinJoinManager doAutomaticDenominating];
}

@end
