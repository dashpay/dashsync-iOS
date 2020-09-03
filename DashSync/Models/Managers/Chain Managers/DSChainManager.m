//
//  DSChainManager.m
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DSChainManager+Protected.h"
#import "DSPeerManager+Protected.h"
#import "DSEventManager.h"
#import "DSChain+Protected.h"
#import "DSSporkManager+Protected.h"
#import "DSOptionsManager.h"
#import "DSMasternodeManager+Protected.h"
#import "DSGovernanceSyncManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "DSIdentitiesManager.h"
#import "DSBloomFilter.h"
#import "DSMerkleBlock.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "NSDate+Utils.h"
#import "DashSync.h"
#import "DSChainEntity+CoreDataClass.h"
#import "RHIntervalTree.h"
#import "DSWallet+Protected.h"
#import "DSFullBlock.h"
#import "DSCheckpoint.h"

#define SYNC_STARTHEIGHT_KEY @"SYNC_STARTHEIGHT"
#define TERMINAL_SYNC_STARTHEIGHT_KEY @"TERMINAL_SYNC_STARTHEIGHT"

@interface DSChainManager ()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) DSSporkManager * sporkManager;
@property (nonatomic, strong) DSMasternodeManager * masternodeManager;
@property (nonatomic, strong) DSGovernanceSyncManager * governanceSyncManager;
@property (nonatomic, strong) DSIdentitiesManager * identitiesManager;
@property (nonatomic, strong) DSDAPIClient * DAPIClient;
@property (nonatomic, strong) DSTransactionManager * transactionManager;
@property (nonatomic, strong) DSPeerManager * peerManager;
@property (nonatomic, assign) uint32_t chainSyncStartHeight;
@property (nonatomic, assign) uint32_t terminalSyncStartHeight;
@property (nonatomic, assign) uint64_t sessionConnectivityNonce;
@property (nonatomic, assign) BOOL gotSporksAtChainSyncStart;
@property (nonatomic, strong) NSData * maxTransactionsInfoData;
@property (nonatomic, strong) RHIntervalTree * heightTransactionZones;
@property (nonatomic, assign) uint32_t maxTransactionsInfoDataFirstHeight;
@property (nonatomic, assign) uint32_t maxTransactionsInfoDataLastHeight;
@property (nonatomic, strong) NSData * chainSynchronizationFingerprint;
@property (nonatomic, strong) NSOrderedSet * chainSynchronizationBlockZones;
@property (nonatomic, strong) dispatch_queue_t miningQueue;

@end

@implementation DSChainManager

- (instancetype)initWithChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    self.syncPhase = DSChainSyncPhase_Offline;
    chain.chainManager = self;
    self.sporkManager = [[DSSporkManager alloc] initWithChain:chain];
    self.masternodeManager = [[DSMasternodeManager alloc] initWithChain:chain];
    self.DAPIClient = [[DSDAPIClient alloc] initWithChain:chain]; //this must be
    [self.masternodeManager setUp];
    self.governanceSyncManager = [[DSGovernanceSyncManager alloc] initWithChain:chain];
    self.transactionManager = [[DSTransactionManager alloc] initWithChain:chain];
    self.peerManager = [[DSPeerManager alloc] initWithChain:chain];
    self.identitiesManager = [[DSIdentitiesManager alloc] initWithChain:chain];
    self.gotSporksAtChainSyncStart = FALSE;
    self.sessionConnectivityNonce = (long long) arc4random() << 32 | arc4random();
    
    if (self.masternodeManager.currentMasternodeList) {
        [self.peerManager useMasternodeList:self.masternodeManager.currentMasternodeList withConnectivityNonce:self.sessionConnectivityNonce];
    }
    
    //[self loadMaxTransactionInfo];
    //[self loadHeightTransactionZones];
    
    _miningQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.mining.%@",self.chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    
    return self;
}

// MARK: - Max transaction info

-(void)loadMaxTransactionInfo {
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:[NSString stringWithFormat:@"MaxTransactionInfo_%@",self.chain.name] ofType:@"dat"];
    self.maxTransactionsInfoData = [NSData dataWithContentsOfFile:filePath];
    if (self.maxTransactionsInfoData) {
        self.maxTransactionsInfoDataFirstHeight = [self.maxTransactionsInfoData UInt16AtOffset:0]*500;
        self.maxTransactionsInfoDataLastHeight = [self.maxTransactionsInfoData UInt16AtOffset:self.maxTransactionsInfoData.length -6] * 500;
        //We need MaxTransactionsInfoDataLastHeight to be after the last checkpoint so there is no gap in info. We can gather Max Transactions after the last checkpoint from the initial terminal sync.
        NSAssert(self.maxTransactionsInfoDataLastHeight > self.chain.checkpoints.lastObject.height, @"MaxTransactionsInfoDataLastHeight should always be after the last checkpoint for the system to work");
    }
    
////Some code to log checkpoints, keep it here for some testing in the future.
//    for (DSCheckpoint * checkpoint in self.chain.checkpoints) {
//        if (checkpoint.height > 340000) {
//            NSLog(@"%d:%d",checkpoint.height,[self averageTransactionsFor500RangeAtHeight:checkpoint.height]);
//        }
//    }
//    float average = 0;
//    uint32_t startRange = self.maxTransactionsInfoDataFirstHeight;
//    NSMutableData * data = [NSMutableData data];
//    [data appendUInt16:startRange/500];
//    while (startRange < self.maxTransactionsInfoDataLastHeight) {
//        uint32_t endRange = [self firstHeightOutOfAverageRangeWithStart500RangeHeight:startRange rAverage:&average];
//        NSLog(@"heights %d-%d averageTransactions %.1f",startRange,endRange,average);
//        startRange = endRange;
//        [data appendUInt16:(unsigned short)average];
//        [data appendUInt16:endRange/500];
//    }
//
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"HeightTransactionZones_%@.dat",self.chain.name]];
//    [data writeToFile:dataPath atomically:YES];
//
}

-(void)loadHeightTransactionZones {
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:[NSString stringWithFormat:@"HeightTransactionZones_%@",self.chain.name] ofType:@"dat"];
    NSData * heightTransactionZonesData = [NSData dataWithContentsOfFile:filePath];
    if (heightTransactionZonesData) {
        NSMutableArray * intervals = [NSMutableArray array];
        for (uint16_t i = 0; i<heightTransactionZonesData.length - 4;i+=4) {
            uint32_t intervalStartHeight = [heightTransactionZonesData UInt16AtOffset:i]*500;
            uint16_t average = [heightTransactionZonesData UInt16AtOffset:i + 2];
            uint32_t intervalEndHeight = [heightTransactionZonesData UInt16AtOffset:i + 4]*500;
            [intervals addObject:[RHInterval intervalWithStart:intervalStartHeight stop:intervalEndHeight -1 object:@(average)]];
        }
        self.heightTransactionZones = [[RHIntervalTree alloc] initWithIntervalObjects:intervals];
    }
}

-(uint16_t)averageTransactionsInZoneForStartHeight:(uint32_t)startHeight endHeight:(uint32_t)endHeight {
    NSArray <RHInterval*>* intervals = [self.heightTransactionZones overlappingObjectsForStart:startHeight andStop:endHeight];
    if (!intervals.count) return 0;
    if (intervals.count == 1) return [(NSNumber*)[intervals[0] object] unsignedShortValue];
    uint64_t aggregate = 0;
    for (RHInterval * interval in intervals) {
        uint64_t value = [(NSNumber*)interval.object unsignedLongValue];
        if (interval == [intervals firstObject]) {
            aggregate += value*(interval.stop - startHeight + 1);
        } else if (interval == [intervals lastObject]) {
            aggregate += value*(endHeight - interval.start + 1);
        } else {
            aggregate += value*(interval.stop - interval.start + 1);
        }
    }
    return aggregate / (endHeight - startHeight);
}

-(uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height rAverage:(float*)rAverage {
    return [self firstHeightOutOfAverageRangeWithStart500RangeHeight:height startingVarianceLevel:1 endingVarianceLevel:0.2 convergencePolynomial:0.33 rAverage:rAverage];
}

-(uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height startingVarianceLevel:(float)startingVarianceLevel endingVarianceLevel:(float)endingVarianceLevel convergencePolynomial:(float)convergencePolynomial rAverage:(float*)rAverage {
    return [self firstHeightOutOfAverageRangeWithStart500RangeHeight:height startingVarianceLevel:startingVarianceLevel endingVarianceLevel:endingVarianceLevel convergencePolynomial:convergencePolynomial recursionLevel:0 recursionMaxLevel:2 rAverage:rAverage rAverages:nil];
}

-(uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height startingVarianceLevel:(float)startingVarianceLevel endingVarianceLevel:(float)endingVarianceLevel convergencePolynomial:(float)convergencePolynomial recursionLevel:(uint16_t)recursionLevel recursionMaxLevel:(uint16_t)recursionMaxLevel rAverage:(float*)rAverage rAverages:(NSArray**)rAverages {
    NSMutableArray * averagesAtHeights = [NSMutableArray array];
    float currentAverage = 0;
    uint32_t checkHeight = height;
    uint16_t i = 0;
    float internalVarianceParameter = ((startingVarianceLevel-endingVarianceLevel)/endingVarianceLevel);
    while (checkHeight < self.maxTransactionsInfoDataLastHeight) {
        uint16_t averageValue = [self averageTransactionsFor500RangeAtHeight:checkHeight];
        
        if (i != 0 && averageValue > 10) { //before 12 just ignore
            float maxVariance = endingVarianceLevel*(powf((float)i,convergencePolynomial)+internalVarianceParameter)/powf((float)i,convergencePolynomial);
            //NSLog(@"height %d averageValue %hu currentAverage %.2f variance %.2f",checkHeight,averageValue,currentAverage,fabsf(averageValue - currentAverage)/currentAverage);
            if (fabsf(averageValue - currentAverage) > maxVariance*currentAverage) {
                //there was a big change in variance
                if (recursionLevel > recursionMaxLevel) break; //don't recurse again
                //We need to make sure that this wasn't a 1 time variance
                float nextAverage = 0;
                NSArray * nextAverages = nil;
                
                uint32_t nextHeight = [self firstHeightOutOfAverageRangeWithStart500RangeHeight:checkHeight startingVarianceLevel:startingVarianceLevel endingVarianceLevel:endingVarianceLevel convergencePolynomial:convergencePolynomial recursionLevel:recursionLevel + 1 recursionMaxLevel:recursionMaxLevel rAverage:&nextAverage rAverages:&nextAverages];
                if (fabsf(nextAverage - currentAverage) > endingVarianceLevel*currentAverage) {
                    break;
                } else {
                    [averagesAtHeights addObjectsFromArray:nextAverages];
                    checkHeight = nextHeight;
                }
            } else {
                [averagesAtHeights addObject:@(averageValue)];
                currentAverage =  [[averagesAtHeights valueForKeyPath:@"@avg.self"] floatValue];
                checkHeight += 500;
            }
        } else {
            [averagesAtHeights addObject:@(averageValue)];
            currentAverage = [[averagesAtHeights valueForKeyPath:@"@avg.self"] floatValue];
            checkHeight += 500;
        }
        i++;
        
    }
    if (rAverage) {
        *rAverage = currentAverage;
    }
    if (rAverages) {
        *rAverages = averagesAtHeights;
    }
    return checkHeight;
}

-(uint16_t)averageTransactionsFor500RangeAtHeight:(uint32_t)height {
    if (height < self.maxTransactionsInfoDataFirstHeight) return 0;
    if (height > self.maxTransactionsInfoDataFirstHeight + self.maxTransactionsInfoData.length * 500 / 6) return 0;
    uint32_t offset = floor(((double)height - self.maxTransactionsInfoDataFirstHeight)*2.0/500.0)*3;
    //uint32_t checkHeight = [self.maxTransactionsInfoData UInt16AtOffset:offset]*500;
    uint16_t average = [self.maxTransactionsInfoData UInt16AtOffset:offset + 2];
    uint16_t max = [self.maxTransactionsInfoData UInt16AtOffset:offset + 4];
    NSAssert(average < max, @"Sanity check that average < max");
    return average;
}

-(uint16_t)maxTransactionsFor500RangeAtHeight:(uint32_t)height {
    if (height < self.maxTransactionsInfoDataFirstHeight) return 0;
    if (height > self.maxTransactionsInfoDataFirstHeight + self.maxTransactionsInfoData.length * 500 / 6) return 0;
    uint32_t offset = floor(((double)height - self.maxTransactionsInfoDataFirstHeight)*2.0/500.0)*3;
    //uint32_t checkHeight = [self.maxTransactionsInfoData UInt16AtOffset:offset]*500;
    uint16_t average = [self.maxTransactionsInfoData UInt16AtOffset:offset + 2];
    uint16_t max = [self.maxTransactionsInfoData UInt16AtOffset:offset + 4];
    NSAssert(average < max, @"Sanity check that average < max");
    return max;
}

// MARK: - Info

-(NSString*)chainSyncStartHeightKey {
    return [NSString stringWithFormat:@"%@_%@",SYNC_STARTHEIGHT_KEY,[self.chain uniqueID]];
}

-(NSString*)terminalSyncStartHeightKey {
    return [NSString stringWithFormat:@"%@_%@",TERMINAL_SYNC_STARTHEIGHT_KEY,[self.chain uniqueID]];
}

- (double)chainSyncProgress
{
    if (! self.peerManager.downloadPeer && self.chainSyncStartHeight == 0) return 0.0;
    //if (self.downloadPeer.status != DSPeerStatus_Connected) return 0.05;
    if (self.chain.lastSyncBlockHeight >= self.chain.estimatedBlockHeight) return 1.0;
    
    double lastBlockHeight = self.chain.lastSyncBlockHeight;
    double estimatedBlockHeight = self.chain.estimatedBlockHeight;
    double syncStartHeight = self.chainSyncStartHeight;
    double progress;
    if (syncStartHeight > lastBlockHeight) {
        progress = lastBlockHeight / estimatedBlockHeight;
    }
    else {
        progress = (lastBlockHeight - syncStartHeight) / (estimatedBlockHeight - syncStartHeight);
    }
    return MIN(1.0, MAX(0.0, 0.1 + 0.9 * progress));
}

-(double)terminalHeaderSyncProgress
{
    if (! self.peerManager.downloadPeer && self.terminalSyncStartHeight == 0) return 0.0;
    if (self.chain.lastTerminalBlockHeight >= self.chain.estimatedBlockHeight) return 1.0;
    
    double lastBlockHeight = self.chain.lastTerminalBlockHeight;
    double estimatedBlockHeight = self.chain.estimatedBlockHeight;
    double syncStartHeight = self.terminalSyncStartHeight;
    double progress;
    if (syncStartHeight > lastBlockHeight) {
        progress = lastBlockHeight / estimatedBlockHeight;
    }
    else {
        progress = (lastBlockHeight - syncStartHeight) / (estimatedBlockHeight - syncStartHeight);
    }
    return MIN(1.0, MAX(0.0, 0.1 + 0.9 * progress));
}

-(double)combinedSyncProgress
{
    DSDLog(@"%f %f %f",self.terminalHeaderSyncProgress,self.masternodeManager.masternodeListAndQuorumsSyncProgress,self.chainSyncProgress);
    return self.terminalHeaderSyncProgress * 0.2 + self.masternodeManager.masternodeListAndQuorumsSyncProgress * 0.25 + self.chainSyncProgress * 0.55;
}

-(void)resetChainSyncStartHeight {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.chainSyncStartHeight == 0) self.chainSyncStartHeight = (uint32_t)[userDefaults integerForKey:self.chainSyncStartHeightKey];
    
    if (self.chainSyncStartHeight == 0) {
        self.chainSyncStartHeight = self.chain.lastSyncBlockHeight;
        [[NSUserDefaults standardUserDefaults] setInteger:self.chainSyncStartHeight forKey:self.chainSyncStartHeightKey];
    }
}

-(void)restartChainSyncStartHeight {
    self.chainSyncStartHeight = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:self.chainSyncStartHeightKey];
}


-(void)resetTerminalSyncStartHeight {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.terminalSyncStartHeight == 0) self.terminalSyncStartHeight = (uint32_t)[userDefaults integerForKey:self.terminalSyncStartHeightKey];
    
    if (self.terminalSyncStartHeight == 0) {
        self.terminalSyncStartHeight = self.chain.lastTerminalBlockHeight;
        [[NSUserDefaults standardUserDefaults] setInteger:self.terminalSyncStartHeight forKey:self.terminalSyncStartHeightKey];
    }
}

-(void)restartTerminalSyncStartHeight {
    self.terminalSyncStartHeight = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:self.terminalSyncStartHeightKey];
}

- (void)relayedNewItem {
    self.lastChainRelayTime = [NSDate timeIntervalSince1970];
}

-(void)resetLastRelayedItemTime {
    self.lastChainRelayTime = 0;
}

// MARK: - Mining

- (void)mineEmptyBlocks:(uint32_t)blockCount toPaymentAddress:(NSString*)paymentAddress withTimeout:(NSTimeInterval)timeout completion:(MultipleBlockMiningCompletionBlock)completion {
    [self mineEmptyBlocks:blockCount toPaymentAddress:paymentAddress afterBlock:self.chain.lastTerminalBlock previousBlocks:self.chain.terminalBlocks withTimeout:timeout completion:completion];
}

- (void)mineEmptyBlocks:(uint32_t)blockCount toPaymentAddress:(NSString*)paymentAddress afterBlock:(DSBlock*)previousBlock previousBlocks:(NSDictionary<NSValue*,DSBlock*>*)previousBlocks withTimeout:(NSTimeInterval)timeout completion:(MultipleBlockMiningCompletionBlock)completion {
    dispatch_async(_miningQueue, ^{
        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval end = [[[NSDate alloc] initWithTimeIntervalSinceNow:timeout] timeIntervalSince1970];
        NSMutableArray * blocksArray = [NSMutableArray array];
        NSMutableArray * attemptsArray = [NSMutableArray array];
        __block uint32_t blocksRemaining = blockCount;
        __block NSMutableDictionary<NSValue*,DSBlock*> * mPreviousBlocks = [previousBlocks mutableCopy];
        __block DSBlock * currentBlock = previousBlock;
        while ([[NSDate date] timeIntervalSince1970] < end && blocksRemaining>0) {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            [self mineBlockAfterBlock:currentBlock toPaymentAddress:paymentAddress withTransactions:[NSArray array] previousBlocks:mPreviousBlocks nonceOffset:0 withTimeout:timeout completion:^(DSFullBlock * _Nullable block, NSUInteger attempts, NSTimeInterval timeUsed, NSError * _Nullable error) {
                NSAssert(!uint256_is_zero(block.blockHash), @"Block hash must not be empty");
                dispatch_semaphore_signal(sem);
                [blocksArray addObject:block];
                [mPreviousBlocks setObject:block forKey:uint256_obj(block.blockHash)];
                currentBlock = block;
                blocksRemaining--;
                [attemptsArray addObject:@(attempts)];
            }];
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(blocksArray,attemptsArray,[[NSDate date] timeIntervalSince1970] - start,nil);
            });
        }
    });
    
}

- (void)mineBlockToPaymentAddress:(NSString*)paymentAddress withTransactions:(NSArray<DSTransaction*>*)transactions withTimeout:(NSTimeInterval)timeout completion:(BlockMiningCompletionBlock)completion {
    [self mineBlockAfterBlock:self.chain.lastTerminalBlock toPaymentAddress:paymentAddress withTransactions:transactions previousBlocks:self.chain.terminalBlocks nonceOffset:0 withTimeout:timeout completion:completion];
}

- (void)mineBlockAfterBlock:(DSBlock*)block toPaymentAddress:(NSString*)paymentAddress withTransactions:(NSArray<DSTransaction*>*)transactions previousBlocks:(NSDictionary<NSValue*,DSBlock*>*)previousBlocks nonceOffset:(uint32_t)nonceOffset withTimeout:(NSTimeInterval)timeout completion:(nonnull BlockMiningCompletionBlock)completion {
    DSCoinbaseTransaction * coinbaseTransaction = [[DSCoinbaseTransaction alloc] initWithCoinbaseMessage:@"From iOS" paymentAddresses:@[paymentAddress] atHeight:block.height + 1 onChain:block.chain];
    DSFullBlock * fullblock = [[DSFullBlock alloc] initWithCoinbaseTransaction:coinbaseTransaction transactions:[NSSet set] previousBlockHash:block.blockHash previousBlocks:previousBlocks timestamp:[[NSDate date] timeIntervalSince1970] height:block.height + 1 onChain:self.chain];
    uint64_t attempts = 0;
    NSDate * startTime = [NSDate date];
    if ([fullblock mineBlockAfterBlock:block withNonceOffset:nonceOffset withTimeout:timeout rAttempts:&attempts]) {
        if (completion) {
            completion(fullblock, attempts, -[startTime timeIntervalSinceNow],nil);
        }
    } else {
        if (completion) {
            NSError * error = [NSError errorWithDomain:@"DashSync" code:500 userInfo:@{NSLocalizedDescriptionKey: DSLocalizedString(@"A block could not be mined in the selected time interval.", nil)}];
            completion(nil, attempts, -[startTime timeIntervalSinceNow],error);
        }
    }
}

// MARK: - Blockchain Sync

- (void)startSync {
    if ([self.identitiesManager unsyncedBlockchainIdentities].count) {
        [self.identitiesManager syncBlockchainIdentitiesWithCompletion:^(BOOL success, NSArray<DSBlockchainIdentity *> * _Nullable blockchainIdentities, NSArray<NSError *> * _Nonnull errors) {
            if (success) {
                [self.peerManager connect];
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self startSync];
                });
            }
        }];
    } else {
        
        [self.peerManager connect];
    }
    
}

- (void)stopSync {
    
    [self.peerManager disconnect];
    self.syncPhase = DSChainSyncPhase_Offline;
}

-(void)disconnectedRescan {
    NSManagedObjectContext * chainContext = [NSManagedObjectContext chainContext];
    DSChainEntity * chainEntity = [self.chain chainEntityInContext:chainContext];
    [chainEntity.managedObjectContext performBlockAndWait:^{
        [self.chain wipeMasternodesInContext:chainEntity.managedObjectContext];//masternodes and quorums must go first
        [DSMerkleBlockEntity deleteBlocksOnChainEntity:chainEntity];
        [DSTransactionHashEntity deleteTransactionHashesOnChainEntity:chainEntity];
        [self.masternodeManager wipeMasternodeInfo];
        [self.chain wipeBlockchainInfoInContext:chainContext];
        [chainContext ds_save];
    }];
    
    NSManagedObjectContext * peerContext =  [NSManagedObjectContext peerContext];
    DSChainEntity * chainEntityInPeerContext = [self.chain chainEntityInContext:peerContext];
    
    if (![self.chain isMainnet]) {
        [self.chain.chainManager.peerManager removeTrustedPeerHost];
        [self.chain.chainManager.peerManager clearPeers];
        [DSPeerEntity deletePeersForChainEntity:chainEntityInPeerContext];
        [peerContext ds_save];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        
    });
    
    self.chainSyncStartHeight = self.chain.lastSyncBlockHeight;
    [[NSUserDefaults standardUserDefaults] setInteger:self.chainSyncStartHeight forKey:self.chainSyncStartHeightKey];
    [self.peerManager connect];
}

-(void)disconnectedRescanOfMasternodeListsAndQuorums {
    NSManagedObjectContext * chainContext = [NSManagedObjectContext chainContext];
    DSChainEntity * chainEntity = [self.chain chainEntityInContext:chainContext];
    [chainEntity.managedObjectContext performBlockAndWait:^{
        [self.chain wipeMasternodesInContext:chainEntity.managedObjectContext];//masternodes and quorums must go first
        [self.masternodeManager wipeMasternodeInfo];
        [chainContext ds_save];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        
    });
    [self.peerManager connect];
}

// rescans blocks and transactions after earliestKeyTime, a new random download peer is also selected due to the
// possibility that a malicious node might lie by omitting transactions that match the bloom filter
- (void)rescan
{
    if (!self.peerManager.connected) {
        [self disconnectedRescan];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil withCompletion:^(BOOL success) {
            [self disconnectedRescan];
        }];
    }
}

- (void)rescanMasternodeListsAndQuorums
{
    if (!self.peerManager.connected) {
        [self disconnectedRescanOfMasternodeListsAndQuorums];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil withCompletion:^(BOOL success) {
            [self disconnectedRescanOfMasternodeListsAndQuorums];
        }];
    }
}


// MARK: - DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes updatedTransactions:(NSArray *)updatedTransactions {
    [self.transactionManager chain:chain didSetBlockHeight:height andTimestamp:timestamp forTransactionHashes:txHashes updatedTransactions:updatedTransactions];
}

-(void)chain:(DSChain*)chain didFinishFetchingBlockchainIdentityDAPInformation:(DSBlockchainIdentity*)blockchainIdentity {
    [self.peerManager resumeBlockchainSynchronizationOnPeers];
}

-(void)chainWasWiped:(DSChain*)chain {
    [self.transactionManager chainWasWiped:chain];
}

-(void)chainWillStartSyncingBlockchain:(DSChain*)chain {
    if (!self.gotSporksAtChainSyncStart) {
        [self.sporkManager getSporks]; //get the sporks early on
    }
}

-(NSData*)chainSynchronizationFingerprint {
//    if (!_chainSynchronizationFingerprint) {
//        _chainSynchronizationFingerprint = @"".hexToData;
//    }
    return _chainSynchronizationFingerprint;
}


-(NSOrderedSet*)chainSynchronizationBlockZones {
    if (!_chainSynchronizationBlockZones) {
        
        _chainSynchronizationBlockZones = [DSWallet blockZonesFromChainSynchronizationFingerprint:self.chainSynchronizationFingerprint rVersion:0 rChainHeight:0];
    }
    return _chainSynchronizationBlockZones;
}

- (BOOL)shouldRequestMerkleBlocksForZoneBetweenHeight:(uint32_t)blockHeight andEndHeight:(uint32_t)endBlockHeight {
    uint16_t blockZone = blockHeight /500;
    uint16_t endBlockZone = endBlockHeight/500 + (endBlockHeight%500?1:0);
    if (self.chainSynchronizationFingerprint) {
        while (blockZone < endBlockZone) {
            if ([[self chainSynchronizationBlockZones] containsObject:@(blockZone)]) return TRUE;
        }
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)shouldRequestMerkleBlocksForZoneAfterHeight:(uint32_t)blockHeight {
    uint16_t blockZone = blockHeight /500;
    uint16_t leftOver = blockHeight %500;
    if (self.chainSynchronizationFingerprint) {
        return [[self chainSynchronizationBlockZones] containsObject:@(blockZone)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 1)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 2)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 3)] || (!leftOver && [self shouldRequestMerkleBlocksForZoneAfterHeight:(blockZone+1)*500]);
    } else {
        return YES;
    }
}

-(void)chainShouldStartSyncingBlockchain:(DSChain*)chain onPeer:(DSPeer*)peer {
    dispatch_async(self.chain.networkingQueue, ^{
        if ((self.syncPhase != DSChainSyncPhase_ChainSync && self.syncPhase != DSChainSyncPhase_Synced) && self.chain.needsInitialTerminalHeadersSync) {
        //masternode list should be synced first and the masternode list is old
            self.syncPhase = DSChainSyncPhase_InitialTerminalBlocks;
            [peer sendGetheadersMessageWithLocators:[self.chain terminalBlocksLocatorArray] andHashStop:UINT256_ZERO];
        } else if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList) && (self.masternodeManager.lastMasternodeListBlockHeight < self.chain.lastTerminalBlockHeight - 8)) {
            self.syncPhase = DSChainSyncPhase_InitialTerminalBlocks;
            [self.masternodeManager getRecentMasternodeList:32 withSafetyDelay:0];
            [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:0];
        } else {
            self.syncPhase = DSChainSyncPhase_ChainSync;
            BOOL startingDevnetSync = [self.chain isDevnetAny] && self.chain.lastSyncBlockHeight < 5;
            NSTimeInterval cutoffTime = self.chain.earliestWalletCreationTime - HEADER_WINDOW_BUFFER_TIME;
            if (startingDevnetSync || (self.chain.lastSyncBlockTimestamp >= cutoffTime && [self shouldRequestMerkleBlocksForZoneAfterHeight:[self.chain lastSyncBlockHeight]]))  {
                
                [peer sendGetblocksMessageWithLocators:[self.chain chainSyncBlockLocatorArray] andHashStop:UINT256_ZERO];
            }
            else {
                [peer sendGetheadersMessageWithLocators:[self.chain chainSyncBlockLocatorArray] andHashStop:UINT256_ZERO];
            }
        }
    });
}

-(void)chainFinishedSyncingInitialHeaders:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) self.lastChainRelayTime = [NSDate timeIntervalSince1970];
    [self.peerManager chainSyncStopped];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getRecentMasternodeList:32 withSafetyDelay:0];
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:0];
    }
}

-(void)chainFinishedSyncingTransactionsAndBlocks:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) self.lastChainRelayTime = [NSDate timeIntervalSince1970];
    DSDLog(@"chain finished syncing");
    self.chainSyncStartHeight = 0;
    self.syncPhase = DSChainSyncPhase_Synced;
    [self.transactionManager fetchMempoolFromNetwork];
    [self.sporkManager getSporks];
    [self.governanceSyncManager startGovernanceSync];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getRecentMasternodeList:32 withSafetyDelay:0];
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:0];
    }
}

-(void)chainFinishedSyncingMasternodeListsAndQuorums:(DSChain*)chain {
    DSDLog(@"Chain finished syncing masternode list and quorums, it should start syncing chain");
    
    if (self.peerManager.connectedPeerCount == 0) {
        if (self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks) {
            self.syncPhase = DSChainSyncPhase_ChainSync;
        }
        [self.peerManager connect];
    } else if (!self.peerManager.masternodeList && self.masternodeManager.currentMasternodeList) {
        [self.peerManager useMasternodeList:self.masternodeManager.currentMasternodeList withConnectivityNonce:self.sessionConnectivityNonce];
    } else {
        if (self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks) {
            self.syncPhase = DSChainSyncPhase_ChainSync;
            [self chainShouldStartSyncingBlockchain:chain onPeer:self.peerManager.downloadPeer];
        }
    }
}

-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer {
    DSDLog(@"peer at address %@ is misbehaving",peer.host);
    [self.peerManager peerMisbehaving:peer errorMessage:@"Bad block received from peer"];
}

-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSBlock*)block fromPeer:(DSPeer*)peer {
    // ignore orphans older than one week ago
    if (block.timestamp < [NSDate timeIntervalSince1970] - WEEK_TIME_INTERVAL) return;
    
    // call getblocks, unless we already did with the previous block, or we're still downloading the chain
    if (self.chain.lastSyncBlockHeight >= peer.lastBlockHeight && ! uint256_eq(self.chain.lastOrphan.blockHash, block.prevBlock)) {
        DSDLog(@"%@:%d calling getblocks", peer.host, peer.port);
        [peer sendGetblocksMessageWithLocators:[self.chain chainSyncBlockLocatorArray] andHashStop:UINT256_ZERO];
    }
}

-(void)chain:(DSChain*)chain wasExtendedWithBlock:(DSBlock*)merkleBlock fromPeer:(DSPeer*)peer {
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:3];
    }
    
}



// MARK: - Count Info

-(void)resetSyncCountInfo:(DSSyncCountInfo)syncCountInfo inContext:(NSManagedObjectContext*)context {
    [self setCount:0 forSyncCountInfo:syncCountInfo inContext:context];
}

-(void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)syncCountInfo inContext:(NSManagedObjectContext*)context {
    switch (syncCountInfo) {
        case DSSyncCountInfo_GovernanceObject:
            self.chain.totalGovernanceObjectsCount = count;
            [self.chain saveInContext:context];
            break;
        case DSSyncCountInfo_GovernanceObjectVote:
            self.governanceSyncManager.currentGovernanceSyncObject.totalGovernanceVoteCount = count;
            [self.governanceSyncManager.currentGovernanceSyncObject save];
            break;
        default:
            break;
    }
}

// MARK: - DSPeerChainDelegate

- (void)peer:(DSPeer *)peer relayedSyncInfo:(DSSyncCountInfo)syncCountInfo count:(uint32_t)count {
    [self setCount:count forSyncCountInfo:syncCountInfo inContext:self.chain.chainManagedObjectContext];
    switch (syncCountInfo) {
        case DSSyncCountInfo_List:
        {
            //deprecated
            break;
        }
        case DSSyncCountInfo_GovernanceObject:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
            });
            break;
        }
        case DSSyncCountInfo_GovernanceObjectVote:
        {
            if (peer.governanceRequestState == DSGovernanceRequestState_GovernanceObjectVoteHashesReceived) {
                if (count == 0) {
                    //there were no votes
                    DSDLog(@"no votes on object, going to next object");
                    peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVotes;
                    [self.governanceSyncManager finishedGovernanceVoteSyncWithPeer:peer];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVoteCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
                    });
                }
            }
            
            break;
        }
        default:
            break;
    }
}

@end
