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

@implementation DSCompactTallyItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _amount = 0;
        _inputCoins = [[NSMutableArray alloc] init];
    }
    return self;
}

- (CompactTallyItem *)ffi_malloc:(ChainType)type {
    CompactTallyItem *tallyItem = malloc(sizeof(CompactTallyItem));
    tallyItem->amount = self.amount;
    
    NSUInteger length = self.txDestination.length;
    tallyItem->tx_destination_length = (uintptr_t)length;
    NSData *scriptData = self.txDestination;
    tallyItem->tx_destination = data_malloc(scriptData);
    
    uintptr_t inputCoinsCount = self.inputCoins.count;
    tallyItem->input_coins_size = inputCoinsCount;
    InputCoin **inputCoins = malloc(inputCoinsCount * sizeof(InputCoin *));
    
    for (uintptr_t i = 0; i < inputCoinsCount; ++i) {
        inputCoins[i] = [self.inputCoins[i] ffi_malloc:type];
    }
    
    tallyItem->input_coins = inputCoins;
    
    return tallyItem;
}

+ (void)ffi_free:(CompactTallyItem *)item {
    if (!item) return;
    
    free(item->tx_destination);
    
    if (item->input_coins_size > 0 && item->input_coins) {
        for (int i = 0; i < item->input_coins_size; i++) {
            [DSInputCoin ffi_free:item->input_coins[i]];
        }
        
        free(item->input_coins);
    }
    
    free(item);
}

@end
