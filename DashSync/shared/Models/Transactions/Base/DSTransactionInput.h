//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

typedef union _UInt256 UInt256;

@interface DSTransactionInput : NSObject

@property (nonatomic, readonly) UInt256 inputHash;
@property (nonatomic, readonly) uint32_t index;
@property (nonatomic, strong, nullable) NSData *inScript;
@property (nonatomic, strong, nullable) NSData *signature;
@property (nonatomic, assign) uint32_t sequence;

+ (instancetype)transactionInputWithHash:(UInt256)inputHash index:(uint32_t)index inScript:(NSData *)inScript signature:(NSData *)signature sequence:(uint32_t)sequence;

- (NSComparisonResult)compare:(DSTransactionInput *)obj;

@end

NS_ASSUME_NONNULL_END
