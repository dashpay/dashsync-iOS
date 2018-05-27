//
//  DSWallet.m
//  DashSync
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

#import "DSWallet.h"
#import "DSAccount.h"
#import "DSWalletManager.h"

@interface DSWallet()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSMutableDictionary * mAccounts;

@end

@implementation DSWallet

+(DSWallet*)standardWalletForChain:(DSChain*)chain {
    DSWallet * wallet = [[DSWallet alloc] init];
    wallet.chain = chain;
    DSAccount * account = [DSAccount accountWithDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] onWallet:wallet];
    [wallet addAccount:account];
    return wallet;
}

-(void)generateExtendedPublicKeys {
    self.seedRequestBlock(@"Please authorize", 0, ^(NSData * _Nullable seed) {
        if (seed) {
        for (DSAccount * account in self.accounts) {
            for (DSDerivationPath * derivationPath in account.derivationPaths) {
                [[DSWalletManager sharedInstance] setExtendedPublicKeyData:[derivationPath generateExtendedPublicKeyFromSeed:seed] forDerivationPath:derivationPath];
            }
        }
        }
    });
}

-(instancetype)init {
    if (! (self = [super init])) return nil;
    self.mAccounts = [NSMutableDictionary dictionary];
    return self;
}

-(NSArray *)accounts {
    return [self.mAccounts allValues];
}

-(void)addAccount:(DSAccount*)account {
    [self.mAccounts setObject:account forKey:@(account.accountNumber)];
    account.wallet = self;
}

- (DSAccount* _Nullable)accountWithNumber:(NSUInteger)accountNumber {
    return [self.mAccounts objectForKey:@(accountNumber)];
}

// MARK: - Combining Accounts

-(NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:[account registerAddressesWithGapLimit:gapLimit internal:internal]];
    }
    return [mArray copy];
}

- (DSAccount*)accountContainingTransaction:(DSTransaction *)transaction {
    for (DSAccount * account in self.accounts) {
        if ([account containsTransaction:transaction]) return account;
    }
    return FALSE;
}

// all previously generated external addresses
-(NSSet *)allReceiveAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSAccount * account in self.accounts) {
        [mSet addObjectsFromArray:[account externalAddresses]];
    }
    return [mSet copy];
}

// all previously generated internal addresses
-(NSSet *)allChangeAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSAccount * account in self.accounts) {
        [mSet addObjectsFromArray:[account internalAddresses]];
    }
    return [mSet copy];
}

-(NSArray *) allTransactions {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:account.allTransactions];
    }
    return mArray;
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    for (DSAccount * account in self.accounts) {
        DSTransaction * transaction = [account transactionForHash:txHash];
        if (transaction) return transaction;
    }
    return nil;
}

-(NSArray *) unspentOutputs {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:account.unspentOutputs];
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

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    uint64_t received = 0;
    for (DSAccount * account in self.accounts) {
        received += [account amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    uint64_t sent = 0;
    for (DSAccount * account in self.accounts) {
        sent += [account amountSentByTransaction:transaction];
    }
    return sent;
}

// set the block heights and timestamps for the given transactions, use a height of TX_UNCONFIRMED and timestamp of 0 to
// indicate a transaction and it's dependents should remain marked as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    NSMutableArray *updated = [NSMutableArray array];
    
    if (height != TX_UNCONFIRMED && height > self.bestBlockHeight) self.bestBlockHeight = height;
    
    for (DSAccount * account in self.accounts) {
        NSArray * fromAccount = [account setBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes];
        if (fromAccount)
            [updated addObjectsFromArray:fromAccount];
    }
    return updated;
}

- (DSAccount *)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction {
    for (DSAccount * account in self.accounts) {
        DSTransaction * lTransaction = [account transactionForHash:txHash];
        if (lTransaction) {
            if (transaction) *transaction = lTransaction;
            return account;
        }
    }
    return nil;
}

- (BOOL)transactionIsValid:(DSTransaction * _Nonnull)transaction {
    for (DSAccount * account in self.accounts) {
        if (![account transactionIsValid:transaction]) return FALSE;
    }
    return TRUE;
}

// outputs below this amount are uneconomical due to fees
- (uint64_t)minOutputAmount
{
    uint64_t amount = (TX_MIN_OUTPUT_AMOUNT*self.feePerKb + MIN_FEE_PER_KB - 1)/MIN_FEE_PER_KB;
    
    return (amount > TX_MIN_OUTPUT_AMOUNT) ? amount : TX_MIN_OUTPUT_AMOUNT;
}

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size isInstant:(BOOL)isInstant inputCount:(NSInteger)inputCount
{
    if (isInstant) {
        return TX_FEE_PER_INPUT*inputCount;
    } else {
        uint64_t standardFee = ((size + 999)/1000)*TX_FEE_PER_KB; // standard fee based on tx size rounded up to nearest kb
#if (!!FEE_PER_KB_URL)
        uint64_t fee = (((size*self.feePerKb/1000) + 99)/100)*100; // fee using feePerKb, rounded up to nearest 100 satoshi
        return (fee > standardFee) ? fee : standardFee;
#else
        return standardFee;
#endif
        
    }
}

@end
