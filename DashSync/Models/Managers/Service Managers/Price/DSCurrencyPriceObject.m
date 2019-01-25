//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSCurrencyPriceObject.h"

#import "DSPriceManager.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSCurrencyPriceObject

- (nullable instancetype)initWithCode:(NSString *)code price:(NSNumber *)price {
    NSParameterAssert(code);
    if (!code) {
        return nil;
    }
    NSString *name = [DSPriceManager sharedInstance].currenciesByCode[code];
    if (!name) {
        // unknown currency, skip it
        return nil;
    }

    return [self initWithCode:code name:name price:price];
}

- (nullable instancetype)initWithCode:(NSString *)code name:(NSString *)name price:(NSNumber *)price {
    NSParameterAssert(code);
    if (!code) {
        return nil;
    }

    self = [super init];
    if (self) {
        _code = [code copy];
        _name = [name copy];
        _price = price;
    }
    return self;
}

- (NSString *)codeAndName {
    return [NSString stringWithFormat:@"%@ - %@", self.code, self.name];
}

- (BOOL)isEqualToPriceObject:(DSCurrencyPriceObject *)object {
    if (!object) {
        return NO;
    }
    
    BOOL haveEqualCodeObjects = (self.code == object.code) || [self.code isEqual:object.code];
    if (!haveEqualCodeObjects) {
        return NO;
    }
    
    BOOL haveEqualNameObjects = (self.name == object.name) || [self.name isEqual:object.name];
    if (!haveEqualNameObjects) {
        return NO;
    }
    
    BOOL haveEqualPriceObjects = (self.price == object.price) || [self.price isEqual:object.price];
    if (!haveEqualPriceObjects) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToPriceObject:object];
}

- (NSUInteger)hash {
    return self.code.hash ^ self.name.hash ^ self.price.hash;
}

@end

NS_ASSUME_NONNULL_END
