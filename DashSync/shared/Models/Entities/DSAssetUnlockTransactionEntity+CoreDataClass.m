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
#import "DSAssetUnlockTransaction.h"
#import "DSAssetUnlockTransactionEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSAssetUnlockTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)transaction {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:transaction];
        DSAssetUnlockTransaction *tx = (DSAssetUnlockTransaction *)transaction;
        self.specialTransactionVersion = tx.specialTransactionVersion;
        self.index = tx.index;
        self.fee = tx.fee;
        self.requestedHeight = tx.requestedHeight;
        self.quorumHash = uint256_data(tx.quorumHash);
        self.quorumSignature = uint768_data(tx.quorumSignature);
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSAssetUnlockTransaction *tx = (DSAssetUnlockTransaction *)[super transactionForChain:chain];
    tx.type = DSTransactionType_AssetUnlock;
    tx.version = SPECIAL_TX_VERSION;
    [self.managedObjectContext performBlockAndWait:^{
        tx.specialTransactionVersion = self.specialTransactionVersion;
        tx.index = self.index;
        tx.fee = self.fee;
        tx.requestedHeight = self.requestedHeight;
        tx.quorumHash = self.quorumHash.UInt256;
        tx.quorumSignature = self.quorumSignature.UInt768;
    }];

    return tx;
}

- (Class)transactionClass {
    return [DSAssetUnlockTransaction class];
}

@end
