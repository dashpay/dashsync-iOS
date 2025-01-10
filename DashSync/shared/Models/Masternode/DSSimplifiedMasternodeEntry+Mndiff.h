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

#import "DSChain.h"
#import "DSSimplifiedMasternodeEntry.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSSimplifiedMasternodeEntry (Mndiff)

//+ (instancetype)simplifiedEntryWith:(MasternodeEntry *)entry onChain:(DSChain *)chain;
//+ (NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedEntriesWith:(MasternodeEntry *_Nullable *_Nonnull)entries count:(uintptr_t)count onChain:(DSChain *)chain;
//
//- (MasternodeEntry *)ffi_malloc;
//+ (void)ffi_free:(MasternodeEntry *)entry;

@end

NS_ASSUME_NONNULL_END
