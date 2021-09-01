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

#import "DSTransactionOutput.h"
#import "DSChain.h"
#import "NSString+Dash.h"

@interface DSTransactionOutput ()

@property (nonatomic, assign) uint64_t amount;
@property (nonatomic, strong) NSData *outScript;
@property (nonatomic, copy) NSString *address;

@end

@implementation DSTransactionOutput

+ (instancetype)transactionOutputWithAmount:(uint64_t)amount outScript:(NSData *)outScript onChain:(DSChain *)chain {
    return [[self alloc] initWithOutputWithAmount:amount outScript:outScript onChain:chain];
}

+ (instancetype)transactionOutputWithAmount:(uint64_t)amount address:(NSString *)address outScript:(NSData *)outScript onChain:(DSChain *)chain {
    return [[self alloc] initWithOutputWithAmount:amount address:address outScript:outScript onChain:chain];
}

- (instancetype)initWithOutputWithAmount:(uint64_t)amount outScript:(NSData *)outScript onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.amount = amount;
    self.outScript = outScript;
    if (outScript) {
        self.address = [NSString addressWithScriptPubKey:outScript onChain:chain]; // address from output script if applicable
    }
    return self;
}

- (instancetype)initWithOutputWithAmount:(uint64_t)amount address:(NSString *)address outScript:(NSData *)outScript onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.amount = amount;
    self.outScript = outScript;
    self.address = address;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@(amount=%llu, outScript=%@, address=%@)",
            [[self class] description], self.amount, self.outScript, self.address];
}

@end
