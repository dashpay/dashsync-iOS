//
//  Created by Vladimir Pirogov
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

#import "DSAddressEntity+CoreDataClass.h"
#import "DSAssetLockTransaction.h"
#import "DSAssetLockTransactionEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSKeyManager.h"
#import "DSTransactionFactory.h"
#import "DSTransactionOutput.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSString+Dash.h"

@implementation DSAssetLockTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)transaction {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:transaction];
        DSAssetLockTransaction *tx = (DSAssetLockTransaction *)transaction;
        self.specialTransactionVersion = tx.specialTransactionVersion;
        NSMutableOrderedSet *creditOutputs = [self mutableOrderedSetValueForKey:@"creditOutputs"];
        while (creditOutputs.count < tx.creditOutputs.count) {
            [creditOutputs addObject:[DSTxOutputEntity managedObjectInBlockedContext:self.managedObjectContext]];
        }
        while (creditOutputs.count > tx.creditOutputs.count) {
            
            [self removeObjectFromCreditOutputsAtIndex:creditOutputs.count - 1];
        }
        NSUInteger idx = 0;
        for (DSTxOutputEntity *e in creditOutputs) {
            [e setAttributesFromTransaction:tx outputIndex:idx++ forTransactionEntity:self];
        }
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSAssetLockTransaction *tx = (DSAssetLockTransaction *)[super transactionForChain:chain];
    tx.type = DSTransactionType_AssetLock;
    [self.managedObjectContext performBlockAndWait:^{
        tx.specialTransactionVersion = self.specialTransactionVersion;
        for (DSTxOutputEntity *e in self.creditOutputs) {
            NSString *address = e.address;
            if (!address && e.script) {
                address = [DSKeyManager addressWithScriptPubKey:e.script forChain:tx.chain];
            }
            DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:e.value address:address outScript:e.script onChain:tx.chain];
            [tx.creditOutputs addObject:transactionOutput];
        }
    }];

    return tx;
}

- (Class)transactionClass {
    return [DSAssetLockTransactionEntity class];
}

@end
