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
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSKeyManager.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionFactory.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
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
        NSMutableOrderedSet *baseOutputs = [self mutableOrderedSetValueForKey:@"outputs"]; // Explicitly fetch `outputs` from base class
        [creditOutputs removeAllObjects];

        for (NSUInteger idx = 0; idx < tx.creditOutputs.count; idx++) {
            DSTxOutputEntity *e = [DSTxOutputEntity managedObjectInBlockedContext:self.managedObjectContext];
            e.txHash = uint256_data(transaction.txHash);
            e.n = (uint32_t)idx;
            DSTransactionOutput *output = tx.creditOutputs[idx];
            e.address = output.address;
            e.script = output.outScript;
            e.value = output.amount;
            e.transaction = self;
            [creditOutputs addObject:e];
        }

        // Ensure `creditOutputs` are NOT added to `outputs`
        for (DSTxOutputEntity *e in creditOutputs) {
            if ([baseOutputs containsObject:e])
                [baseOutputs removeObject:e]; // Explicitly remove credit outputs from base transaction outputs
        }
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSAssetLockTransaction *tx = (DSAssetLockTransaction *)[super transactionForChain:chain];
    tx.type = DSTransactionType_AssetLock;
    tx.version = SPECIAL_TX_VERSION;

    [self.managedObjectContext performBlockAndWait:^{
        tx.instantSendLockAwaitingProcessing = [self.instantSendLock instantSendTransactionLockForChain:chain];
        tx.specialTransactionVersion = self.specialTransactionVersion;
        NSMutableArray *creditOutputs = [NSMutableArray arrayWithCapacity:self.creditOutputs.count];
        for (DSTxOutputEntity *e in self.creditOutputs) {
            NSString *address = e.address;
            if (!address && e.script) {
                address = [DSKeyManager addressWithScriptPubKey:e.script forChain:tx.chain];
            }
            DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:e.value address:address outScript:e.script onChain:tx.chain];
            [creditOutputs addObject:transactionOutput];
        }
        tx.creditOutputs = creditOutputs;
    }];

    return tx;
}

- (Class)transactionClass {
    return [DSAssetLockTransaction class];
}

@end
