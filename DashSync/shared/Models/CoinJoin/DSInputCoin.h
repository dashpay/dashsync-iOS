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
#import "DSTransactionOutput.h"
#import "BigIntTypes.h"
#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSInputCoin : NSObject

@property (nonatomic, assign) UInt256 outpointHash;
@property (nonatomic, assign) uint32_t outpointIndex;
@property (strong, nonatomic) DSTransactionOutput *output;
@property (nonatomic, assign) uint64_t effectiveValue;

- (instancetype)initWithTx:(DSTransaction *)tx index:(int32_t)i;
- (InputCoin *)ffi_malloc:(ChainType)type;
+ (void)ffi_free:(InputCoin *)inputCoin;

@end

NS_ASSUME_NONNULL_END
