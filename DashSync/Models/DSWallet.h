//
//  DSWallet.h
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

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString* _Nonnull const DSWalletBalanceChangedNotification;

#define DUFFS           100000000LL
#define MAX_MONEY          (21000000LL*DUFFS)
#define DEFAULT_FEE_PER_KB ((5000ULL*100 + 99)/100) // bitcoind 0.11 min relay fee on 100bytes
#define MIN_FEE_PER_KB     ((TX_FEE_PER_KB*1000 + 190)/191) // minimum relay fee on a 191byte tx
#define MAX_FEE_PER_KB     ((100100ULL*1000 + 190)/191) // slightly higher than a 1000bit fee on a 191byte tx

@interface DSWallet : NSObject

@property (nonatomic,strong) NSArray * accounts;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// latest 100 transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * _Nonnull recentTransactions;

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * _Nonnull allTransactions;

// the total amount spent from the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalSent;

// the total amount received by the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalReceived;

// fee per kb of transaction size to use when including tx fee
@property (nonatomic, assign) uint64_t feePerKb;

// outputs below this amount are uneconomical due to fees
@property (nonatomic, readonly) uint64_t minOutputAmount;

@property (nonatomic, assign) uint32_t bestBlockHeight;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString * _Nonnull)address;

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString * _Nonnull)address;

// sets the block heights and timestamps for the given transactions, and returns an array of hashes of the updated tx
// use a height of TX_UNCONFIRMED and timestamp of 0 to indicate a transaction and it's dependents should remain marked
// as unverified (not 0-conf safe)
- (NSArray * _Nonnull)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp
                         forTxHashes:(NSArray * _Nonnull)txHashes;

@end
