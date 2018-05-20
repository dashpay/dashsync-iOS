//
//  DSWallet.m
//  DashSync
//
//  Created by Sam Westrich on 5/20/18.
//

#import "DSWallet.h"
#import "DSAccount.h"

@interface DSWallet()

@end

@implementation DSWallet

// MARK: - Combining Accounts

-(NSArray *) allTransactions {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:account.allTransactions];
    }
    return mArray;
}

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address {
    for (DSAccount * account in self.accounts) {
        if ([account containsAddress:address]) return TRUE;
    }
    return FALSE;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    for (DSAccount * account in self.accounts) {
        if ([account addressIsUsed:address]) return TRUE;
    }
    return FALSE;
}

// set the block heights and timestamps for the given transactions, use a height of TX_UNCONFIRMED and timestamp of 0 to
// indicate a transaction and it's dependents should remain marked as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    NSMutableArray *hashes = [NSMutableArray array], *updated = [NSMutableArray array];
    BOOL needsUpdate = NO;
    
    if (height != TX_UNCONFIRMED && height > self.bestBlockHeight) self.bestBlockHeight = height;
    
    for (NSValue *hash in txHashes) {
        DSTransaction *tx = self.allTx[hash];
        UInt256 h;
        
        if (! tx || (tx.blockHeight == height && tx.timestamp == timestamp)) continue;
        tx.blockHeight = height;
        tx.timestamp = timestamp;
        
        if ([self containsTransaction:tx]) {
            [hash getValue:&h];
            [hashes addObject:[NSData dataWithBytes:&h length:sizeof(h)]];
            [updated addObject:hash];
            if ([self.pendingTx containsObject:hash] || [self.invalidTx containsObject:hash]) needsUpdate = YES;
        }
        else if (height != TX_UNCONFIRMED) [self.allTx removeObjectForKey:hash]; // remove confirmed non-wallet tx
    }
    
    if (hashes.count > 0) {
        if (needsUpdate) {
            [self sortTransactions];
            [self updateBalance];
        }
        
        [self.moc performBlockAndWait:^{
            @autoreleasepool {
                NSMutableSet *entities = [NSMutableSet set];
                
                for (DSTransactionEntity *e in [DSTransactionEntity objectsMatching:@"txHash in %@", hashes]) {
                    e.blockHeight = height;
                    e.timestamp = timestamp;
                    [entities addObject:e];
                }
                
                if (height != TX_UNCONFIRMED) {
                    // BUG: XXX saving the tx.blockHeight and the block it's contained in both need to happen together
                    // as an atomic db operation. If the tx.blockHeight is saved but the block isn't when the app exits,
                    // then a re-org that happens afterward can potentially result in an invalid tx showing as confirmed
                    
                    for (NSManagedObject *e in entities) {
                        [self.moc refreshObject:e mergeChanges:NO];
                    }
                }
            }
        }];
    }
    
    return updated;
}

@end
