//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import <XCTest/XCTest.h>

#import <DashSync/DashSync.h>

@interface DSCoinJoinSessionTest : XCTestCase

@end

@implementation DSCoinJoinSessionTest

- (void)sessionTest {
//    DCoinJoinClientOptions *options = malloc(sizeof(DCoinJoinClientOptions));
    
    DCoinJoinClientOptions *options = dash_spv_coinjoin_models_coinjoin_client_options_CoinJoinClientOptions_ctor(YES, DUFFS / 4, 1, 1, COINJOIN_RANDOM_ROUNDS, DEFAULT_COINJOIN_DENOMS_GOAL, DEFAULT_COINJOIN_DENOMS_HARDCAP, NO, dash_spv_crypto_network_chain_type_ChainType_MainNet_ctor(), NO);
    
    dash_spv_coinjoin_models_coinjoin_client_options_CoinJoinClientOptions_destroy(options);
//    options->enable_coinjoin = YES;
//    options->coinjoin_rounds = 1;
//    options->coinjoin_sessions = 1;
//    options->coinjoin_amount = DUFFS / 4; // 0.25 DASH
//    options->coinjoin_random_rounds = COINJOIN_RANDOM_ROUNDS; // TODO: check
//    options->coinjoin_denoms_goal = DEFAULT_COINJOIN_DENOMS_GOAL;
//    options->coinjoin_denoms_hardcap = DEFAULT_COINJOIN_DENOMS_HARDCAP;
//    options->coinjoin_multi_session = NO;
//
//    // TODO: session test
//    
//    free(options);
}

@end
