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

#import "DSChainManager+Protected.h"
#import "DSChainManager+Transactions.h"
#import "DSWallet+Protected.h"
#import "RHIntervalTree.h"
#import <objc/runtime.h>

NSString const *maxTransactionsInfoDataKey = @"maxTransactionsInfoDataKey";
NSString const *heightTransactionZonesKey = @"heightTransactionZonesKey";
NSString const *maxTransactionsInfoDataFirstHeightKey = @"maxTransactionsInfoDataFirstHeightKey";
NSString const *maxTransactionsInfoDataLastHeightKey = @"maxTransactionsInfoDataLastHeightKey";
NSString const *chainSynchronizationFingerprintKey = @"chainSynchronizationFingerprintKey";
NSString const *chainSynchronizationBlockZonesKey = @"chainSynchronizationBlockZonesKey";


@interface DSChainManager ()

@property (nonatomic, strong) NSData *maxTransactionsInfoData;
@property (nonatomic, strong) RHIntervalTree *heightTransactionZones;
@property (nonatomic, assign) uint32_t maxTransactionsInfoDataFirstHeight;
@property (nonatomic, assign) uint32_t maxTransactionsInfoDataLastHeight;
@property (nonatomic, strong) NSData *chainSynchronizationFingerprint;
@property (nonatomic, strong) NSOrderedSet *chainSynchronizationBlockZones;

@end

@implementation DSChainManager (Transactions)

- (void)setMaxTransactionsInfoData:(NSData *)maxTransactionsInfoData {
    objc_setAssociatedObject(self, &maxTransactionsInfoDataKey, maxTransactionsInfoData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSData *)maxTransactionsInfoData {
    return objc_getAssociatedObject(self, &maxTransactionsInfoDataKey);
}

- (void)setHeightTransactionZones:(RHIntervalTree *)heightTransactionZones {
    objc_setAssociatedObject(self, &heightTransactionZonesKey, heightTransactionZones, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (RHIntervalTree *)heightTransactionZones {
    return objc_getAssociatedObject(self, &heightTransactionZonesKey);
}


- (void)setChainSynchronizationBlockZones:(NSOrderedSet *)chainSynchronizationBlockZones {
    objc_setAssociatedObject(self, &chainSynchronizationBlockZonesKey, chainSynchronizationBlockZones, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSOrderedSet *)chainSynchronizationBlockZones {
    NSOrderedSet *obj = objc_getAssociatedObject(self, &chainSynchronizationBlockZonesKey);
    if (!obj) {
        obj = [DSWallet blockZonesFromChainSynchronizationFingerprint:self.chainSynchronizationFingerprint rVersion:0 rChainHeight:0];
        [self setChainSynchronizationBlockZones:obj];
    }
    return obj;

}

- (void)loadHeightTransactionZones {
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:[NSString stringWithFormat:@"HeightTransactionZones_%@", self.chain.name] ofType:@"dat"];
    NSData *heightTransactionZonesData = [NSData dataWithContentsOfFile:filePath];
    if (heightTransactionZonesData) {
        NSMutableArray *intervals = [NSMutableArray array];
        for (uint16_t i = 0; i < heightTransactionZonesData.length - 4; i += 4) {
            uint32_t intervalStartHeight = [heightTransactionZonesData UInt16AtOffset:i] * 500;
            uint16_t average = [heightTransactionZonesData UInt16AtOffset:i + 2];
            uint32_t intervalEndHeight = [heightTransactionZonesData UInt16AtOffset:i + 4] * 500;
            [intervals addObject:[RHInterval intervalWithStart:intervalStartHeight stop:intervalEndHeight - 1 object:@(average)]];
        }
        self.heightTransactionZones = [[RHIntervalTree alloc] initWithIntervalObjects:intervals];
    }
}

- (uint16_t)averageTransactionsInZoneForStartHeight:(uint32_t)startHeight endHeight:(uint32_t)endHeight {
    NSArray<RHInterval *> *intervals = [self.heightTransactionZones overlappingObjectsForStart:startHeight andStop:endHeight];
    if (!intervals.count) return 0;
    if (intervals.count == 1) return [(NSNumber *)[intervals[0] object] unsignedShortValue];
    uint64_t aggregate = 0;
    for (RHInterval *interval in intervals) {
        uint64_t value = [(NSNumber *)interval.object unsignedLongValue];
        if (interval == [intervals firstObject]) {
            aggregate += value * (interval.stop - startHeight + 1);
        } else if (interval == [intervals lastObject]) {
            aggregate += value * (endHeight - interval.start + 1);
        } else {
            aggregate += value * (interval.stop - interval.start + 1);
        }
    }
    return aggregate / (endHeight - startHeight);
}

- (uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height rAverage:(float *)rAverage {
    return [self firstHeightOutOfAverageRangeWithStart500RangeHeight:height startingVarianceLevel:1 endingVarianceLevel:0.2 convergencePolynomial:0.33 rAverage:rAverage];
}

- (uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height startingVarianceLevel:(float)startingVarianceLevel endingVarianceLevel:(float)endingVarianceLevel convergencePolynomial:(float)convergencePolynomial rAverage:(float *)rAverage {
    return [self firstHeightOutOfAverageRangeWithStart500RangeHeight:height startingVarianceLevel:startingVarianceLevel endingVarianceLevel:endingVarianceLevel convergencePolynomial:convergencePolynomial recursionLevel:0 recursionMaxLevel:2 rAverage:rAverage rAverages:nil];
}

- (uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height startingVarianceLevel:(float)startingVarianceLevel endingVarianceLevel:(float)endingVarianceLevel convergencePolynomial:(float)convergencePolynomial recursionLevel:(uint16_t)recursionLevel recursionMaxLevel:(uint16_t)recursionMaxLevel rAverage:(float *)rAverage rAverages:(NSArray **)rAverages {
    NSMutableArray *averagesAtHeights = [NSMutableArray array];
    float currentAverage = 0;
    uint32_t checkHeight = height;
    uint16_t i = 0;
    float internalVarianceParameter = ((startingVarianceLevel - endingVarianceLevel) / endingVarianceLevel);
    while (checkHeight < self.maxTransactionsInfoDataLastHeight) {
        uint16_t averageValue = [self averageTransactionsFor500RangeAtHeight:checkHeight];

        if (i != 0 && averageValue > 10) { //before 12 just ignore
            float maxVariance = endingVarianceLevel * (powf((float)i, convergencePolynomial) + internalVarianceParameter) / powf((float)i, convergencePolynomial);
            //NSLog(@"height %d averageValue %hu currentAverage %.2f variance %.2f",checkHeight,averageValue,currentAverage,fabsf(averageValue - currentAverage)/currentAverage);
            if (fabsf(averageValue - currentAverage) > maxVariance * currentAverage) {
                //there was a big change in variance
                if (recursionLevel > recursionMaxLevel) break; //don't recurse again
                //We need to make sure that this wasn't a 1 time variance
                float nextAverage = 0;
                NSArray *nextAverages = nil;

                uint32_t nextHeight = [self firstHeightOutOfAverageRangeWithStart500RangeHeight:checkHeight startingVarianceLevel:startingVarianceLevel endingVarianceLevel:endingVarianceLevel convergencePolynomial:convergencePolynomial recursionLevel:recursionLevel + 1 recursionMaxLevel:recursionMaxLevel rAverage:&nextAverage rAverages:&nextAverages];
                if (fabsf(nextAverage - currentAverage) > endingVarianceLevel * currentAverage) {
                    break;
                } else {
                    [averagesAtHeights addObjectsFromArray:nextAverages];
                    checkHeight = nextHeight;
                }
            } else {
                [averagesAtHeights addObject:@(averageValue)];
                currentAverage = [[averagesAtHeights valueForKeyPath:@"@avg.self"] floatValue];
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

- (uint16_t)averageTransactionsFor500RangeAtHeight:(uint32_t)height {
    if (height < self.maxTransactionsInfoDataFirstHeight) return 0;
    if (height > self.maxTransactionsInfoDataFirstHeight + self.maxTransactionsInfoData.length * 500 / 6) return 0;
    uint32_t offset = floor(((double)height - self.maxTransactionsInfoDataFirstHeight) * 2.0 / 500.0) * 3;
    //uint32_t checkHeight = [self.maxTransactionsInfoData UInt16AtOffset:offset]*500;
    uint16_t average = [self.maxTransactionsInfoData UInt16AtOffset:offset + 2];
    uint16_t max = [self.maxTransactionsInfoData UInt16AtOffset:offset + 4];
    NSAssert(average < max, @"Sanity check that average < max");
    return average;
}

- (uint16_t)maxTransactionsFor500RangeAtHeight:(uint32_t)height {
    if (height < self.maxTransactionsInfoDataFirstHeight) return 0;
    if (height > self.maxTransactionsInfoDataFirstHeight + self.maxTransactionsInfoData.length * 500 / 6) return 0;
    uint32_t offset = floor(((double)height - self.maxTransactionsInfoDataFirstHeight) * 2.0 / 500.0) * 3;
    //uint32_t checkHeight = [self.maxTransactionsInfoData UInt16AtOffset:offset]*500;
    uint16_t average = [self.maxTransactionsInfoData UInt16AtOffset:offset + 2];
    uint16_t max = [self.maxTransactionsInfoData UInt16AtOffset:offset + 4];
    NSAssert(average < max, @"Sanity check that average < max");
    return max;
}

- (BOOL)shouldRequestMerkleBlocksForZoneBetweenHeight:(uint32_t)blockHeight andEndHeight:(uint32_t)endBlockHeight {
    uint16_t blockZone = blockHeight / 500;
    uint16_t endBlockZone = endBlockHeight / 500 + (endBlockHeight % 500 ? 1 : 0);
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
    uint16_t blockZone = blockHeight / 500;
    uint16_t leftOver = blockHeight % 500;
    if (self.chainSynchronizationFingerprint) {
        return [[self chainSynchronizationBlockZones] containsObject:@(blockZone)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 1)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 2)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 3)] || (!leftOver && [self shouldRequestMerkleBlocksForZoneAfterHeight:(blockZone + 1) * 500]);
    } else {
        return YES;
    }
}

@end
