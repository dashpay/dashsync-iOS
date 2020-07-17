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

#import "DSBlock.h"
#import "DSTransaction.h"
#import "DSCoinbaseTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSFullBlock : DSBlock

@property (nonatomic,readonly) NSArray <DSTransaction*>* transactions;

-(instancetype)initWithCoinbaseTransaction:(DSCoinbaseTransaction*)coinbaseTransaction transactions:(NSSet<DSTransaction*>*)transactions previousBlockHash:(UInt256)previousBlockHash previousBlocks:(NSDictionary*)previousBlocks timestamp:(uint32_t)timestamp height:(uint32_t)height onChain:(DSChain *)chain;

-(BOOL)mineBlockAfterBlock:(DSBlock*)block withNonceOffset:(uint32_t)nonceOffset withTimeout:(NSTimeInterval)timeout rAttempts:(uint64_t*)rAttempts;

-(void)setTargetWithPreviousBlocks:(NSDictionary*)previousBlocks;

@end

NS_ASSUME_NONNULL_END
