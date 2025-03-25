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

#import "DSCompactTallyItem.h"
#import "DSCoinJoinWrapper.h"

@implementation DSCompactTallyItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _amount = 0;
        _inputCoins = [[NSMutableArray alloc] init];
    }
    return self;
}

- (DCompactTallyItem *)ffi_malloc:(DChainType *)type {
    
    NSUInteger count = self.inputCoins.count;
    DInputCoin **values = malloc(count * sizeof(DInputCoin *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = [self.inputCoins[i] ffi_malloc:type];
    }
    DInputCoins *input_coins =  DInputCoinsCtor(count, values);
    return DCompactTallyItemCtor(bytes_ctor(self.txDestination), self.amount, input_coins);
}

+ (void)ffi_free:(DCompactTallyItem *)item {
    if (!item) return;
    DCompactTallyItemDtor(item);
}

@end
