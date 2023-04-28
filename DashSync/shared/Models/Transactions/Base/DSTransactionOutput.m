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
#import "DSKeyManager.h"

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
        self.address = [DSKeyManager addressWithScriptPubKey:outScript forChain:chain]; // address from output script if applicable
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

- (NSComparisonResult)compare:(DSTransactionOutput *)output2 {
    uint64_t a1 = self.amount;
    uint64_t a2 = output2.amount;
    if (a1 > a2) {
        return NSOrderedDescending;
    } else if (a1 < a2) {
        return NSOrderedAscending;
    } else {
        NSData *script1 = self.outScript;
        NSData *script2 = output2.outScript;
        NSUInteger minLength = MIN(script1.length, script2.length);
        int cmpResult = memcmp(script1.bytes, script2.bytes, minLength);
        if (cmpResult == 0) {
            return (script1.length == script2.length ? NSOrderedSame : (script1.length < script2.length ? NSOrderedAscending : NSOrderedDescending));
        } else {
            return (cmpResult < 0) ? NSOrderedAscending : NSOrderedDescending;
        }
    }
}

- (BOOL)isEqual:(id)object {
    DSTransactionOutput *output = (DSTransactionOutput *)object;
    return self == object ||
           ([object isKindOfClass:[DSTransactionOutput class]] &&
               self.amount == output.amount &&
               ([self.outScript isEqualToData:output.outScript] || (!self.outScript && !output.outScript)) &&
               ([self.address isEqual:output.address] || (!self.address && !output.address)));
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@(amount=%llu, outScript=%@, address=%@)",
                     [[self class] description], self.amount, self.outScript, self.address];
}

@end
