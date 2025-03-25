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

#import <Foundation/Foundation.h>
#import "DSKeyManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSCoinJoinBalance : NSObject

@property (nonatomic, assign) uint64_t myTrusted;
@property (nonatomic, assign) uint64_t denominatedTrusted;
@property (nonatomic, assign) uint64_t anonymized;
@property (nonatomic, assign) uint64_t myImmature;
@property (nonatomic, assign) uint64_t myUntrustedPending;
@property (nonatomic, assign) uint64_t denominatedUntrustedPending;
@property (nonatomic, assign) uint64_t watchOnlyTrusted;
@property (nonatomic, assign) uint64_t watchOnlyUntrustedPending;
@property (nonatomic, assign) uint64_t watchOnlyImmature;

+ (DSCoinJoinBalance *)balanceWithMyTrusted:(uint64_t)myTrusted
                         denominatedTrusted:(uint64_t)denominatedTrusted
                                 anonymized:(uint64_t)anonymized
                                 myImmature:(uint64_t)myImmature
                         myUntrustedPending:(uint64_t)myUntrustedPending
                denominatedUntrustedPending:(uint64_t)denominatedUntrustedPending
                           watchOnlyTrusted:(uint64_t)watchOnlyTrusted
                  watchOnlyUntrustedPending:(uint64_t)watchOnlyUntrustedPending
                          watchOnlyImmature:(uint64_t)watchOnlyImmature;
@end

@interface DSCoinJoinBalance (FFI)

+ (DBalance *)ffi_to:(DSCoinJoinBalance *)obj;
+ (void)ffi_destroy:(DBalance *)ffi_ref;

@end

NS_ASSUME_NONNULL_END
