//
//  Created by Vladimir Pirogov
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

#import "BigIntTypes.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeDiffMessageContext : NSObject

@property (nonatomic) DSChain *chain;
@property (nonatomic, nullable) DSMerkleBlock *lastBlock;
//@property (nonatomic, nullable) NSData *lastBlockMerkleRoot;
@property (nonatomic) BOOL useInsightAsBackup;
@property (nonatomic, copy) DSMasternodeList * (^masternodeListLookup)(UInt256 blockHash);
@property (nonatomic, copy) BlockHeightFinder blockHeightLookup;

@end

NS_ASSUME_NONNULL_END
