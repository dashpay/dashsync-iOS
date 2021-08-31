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

#import "DSTransactionInput.h"
#import "BigIntTypes.h"

@interface DSTransactionInput ()

@property (nonatomic, assign) UInt256 inputHash;
@property (nonatomic, assign) uint32_t index;

@end

@implementation DSTransactionInput

+ (instancetype)transactionInputWithHash:(UInt256)inputHash index:(uint32_t)index inScript:(NSData *)inScript signature:(NSData *)signature sequence:(uint32_t)sequence {
    return [[self alloc] initWithInputWithHash:inputHash index:index inScript:inScript signature:signature sequence:sequence];
}

- (instancetype)initWithInputWithHash:(UInt256)inputHash index:(uint32_t)index inScript:(NSData *)inScript signature:(NSData *)signature sequence:(uint32_t)sequence {
    if (!(self = [super init])) return nil;
    self.inputHash = inputHash;
    self.index = index;
    self.inScript = inScript;
    self.signature = signature;
    self.sequence = sequence;
    return self;
}

@end
