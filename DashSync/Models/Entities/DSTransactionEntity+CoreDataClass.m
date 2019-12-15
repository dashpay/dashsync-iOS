//
//  DSTransactionEntity+CoreDataClass.m
//  
//
//  Created by Sam Westrich on 5/20/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSTransaction+Protected.h"
#import "DSMerkleBlock.h"
#import "NSManagedObject+Sugar.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSInstantSendTransactionLock.h"

@implementation DSTransactionEntity

+ (void)setContext:(NSManagedObjectContext *)context
{
    [super setContext:context];
    [DSTxInputEntity setContext:context];
    [DSTxOutputEntity setContext:context];
}

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        NSMutableOrderedSet *inputs = [self mutableOrderedSetValueForKey:@"inputs"];
        NSMutableOrderedSet *outputs = [self mutableOrderedSetValueForKey:@"outputs"];
        UInt256 txHash = tx.txHash;
        NSUInteger idx = 0;
        if (!self.transactionHash) {
            self.transactionHash = [DSTransactionHashEntity managedObject];
            self.transactionHash.chain = tx.chain.chainEntity;
        } else if (!self.transactionHash.chain) {
            self.transactionHash.chain = tx.chain.chainEntity;
        }
        self.transactionHash.txHash = uint256_data(txHash);
        self.transactionHash.blockHeight = tx.blockHeight;
        self.transactionHash.timestamp = tx.timestamp;
        self.associatedShapeshift = tx.associatedShapeshift;
        
        while (inputs.count < tx.inputHashes.count) {
            [inputs addObject:[DSTxInputEntity managedObject]];
        }
        
        while (inputs.count > tx.inputHashes.count) {
            [inputs removeObjectAtIndex:inputs.count - 1];
        }
        
        for (DSTxInputEntity *e in inputs) {
            [e setAttributesFromTransaction:tx inputIndex:idx++ forTransactionEntity:self];
        }
        
        while (outputs.count < tx.outputAddresses.count) {
            [outputs addObject:[DSTxOutputEntity managedObject]];
        }
        
        while (outputs.count > tx.outputAddresses.count) {
            [self removeObjectFromOutputsAtIndex:outputs.count - 1];
        }
        
        idx = 0;
        
        for (DSTxOutputEntity *e in outputs) {
            [e setAttributesFromTransaction:tx outputIndex:idx++ forTransactionEntity:self];
        }
        
        self.lockTime = tx.lockTime;
        
        
    }];
    
    return self;
}

+ (NSArray<DSTransactionEntity*> *)transactionsForChain:(DSChainEntity*)chain {
    NSMutableArray * transactions = [NSMutableArray array];
    for (DSTransactionHashEntity * hashEntity in chain.transactionHashes) {
        [transactions addObject:hashEntity.transaction];
    }
    return transactions;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    if (!chain) chain = [self.chain chain];
    DSTransaction *tx = [[[self transactionClass] alloc] initOnChain:chain];
    
    [self.managedObjectContext performBlockAndWait:^{
        NSData *txHash = self.transactionHash.txHash;
        
        if (txHash.length == sizeof(UInt256)) tx.txHash = *(const UInt256 *)txHash.bytes;
        tx.lockTime = self.lockTime;
        tx.saved = TRUE;
        
        tx.blockHeight = self.transactionHash.blockHeight;
        tx.timestamp = self.transactionHash.timestamp;
        tx.associatedShapeshift = self.associatedShapeshift;
        
        for (DSTxInputEntity *e in self.inputs) {
            txHash = e.txHash;
            if (txHash.length != sizeof(UInt256)) continue;
            [tx addInputHash:*(const UInt256 *)txHash.bytes index:e.n script:nil signature:e.signature
                    sequence:e.sequence];
        }
        
        for (DSTxOutputEntity *e in self.outputs) {
            [tx addOutputScript:e.script withAddress:e.address amount:e.value];
        }
        
        DSInstantSendTransactionLock * instantSendLock = [self.instantSendLock instantSendTransactionLockForChain:chain];
        [tx setInstantSendReceivedWithInstantSendLock:instantSendLock];
    }];
    
    return tx;
}

- (void)deleteObject
{
    for (DSTxInputEntity *e in self.inputs) { // mark inputs as unspent
        [[DSTxOutputEntity objectsMatching:@"txHash == %@ && n == %d", e.txHash, e.n].lastObject setSpentInInput:nil];
    }
    
    [super deleteObject];
}

-(Class)transactionClass {
    return [DSTransaction class];
}

@end
