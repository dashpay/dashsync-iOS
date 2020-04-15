//
//  DSChainEntity+CoreDataClass.m
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

#import "DSChainEntity+CoreDataProperties.h"
#import "DSPeerManager.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "NSString+Dash.h"
#import "NSData+Bitcoin.h"

@implementation DSChainEntity

- (instancetype)setAttributesFromChain:(DSChain *)chain {
    self.type = chain.chainType;
    self.totalMasternodeCount = chain.totalMasternodeCount;
    self.totalGovernanceObjectsCount = chain.totalGovernanceObjectsCount;
    return self;
}

- (DSChain *)chain {
    __block DSChainType type;
    __block NSString * devnetIdentifier;
    __block NSData * data;
    __block uint32_t totalMasternodeCount;
    __block uint32_t totalGovernanceObjectsCount;
    __block UInt256 baseBlockHash;
    [self.managedObjectContext performBlockAndWait:^{
        type = self.type;
        devnetIdentifier = self.devnetIdentifier;
        data = self.checkpoints;
        totalMasternodeCount = self.totalMasternodeCount;
        totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        baseBlockHash = self.baseBlockHash.UInt256;
    }];
    if (type == DSChainType_MainNet) {
        return [DSChain mainnet];
    } else if (type == DSChainType_TestNet) {
        return [DSChain testnet];
    } else if (type == DSChainType_DevNet) {
        if ([DSChain devnetWithIdentifier:devnetIdentifier]) {
            return [DSChain devnetWithIdentifier:devnetIdentifier];
        } else {
            NSArray * checkpointArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            return [DSChain recoverKnownDevnetWithIdentifier:devnetIdentifier withCheckpoints:checkpointArray];
        }
    }
    NSAssert(FALSE, @"Unknown DSChainType");
    return [DSChain mainnet];
}

+ (DSChainEntity*)chainEntityForType:(DSChainType)type devnetIdentifier:(NSString*)devnetIdentifier checkpoints:(NSArray*)checkpoints {
    NSArray * objects = [DSChainEntity objectsMatching:@"type = %d && ((type != %d) || devnetIdentifier = %@)",type,DSChainType_DevNet,devnetIdentifier];
    if (objects.count) {
        DSChainEntity * chainEntity = [objects objectAtIndex:0];
        NSArray * knownCheckpoints = [NSKeyedUnarchiver unarchiveObjectWithData:[chainEntity checkpoints]];
        if (checkpoints.count > knownCheckpoints.count) {
            NSData * archivedCheckpoints = [NSKeyedArchiver archivedDataWithRootObject:checkpoints];
            chainEntity.checkpoints = archivedCheckpoints;
        }
        return chainEntity;
    }
    
    DSChainEntity * chainEntity = [self managedObject];
    chainEntity.type = type;
    chainEntity.devnetIdentifier = devnetIdentifier;
    if (checkpoints) {
        NSData * archivedCheckpoints = [NSKeyedArchiver archivedDataWithRootObject:checkpoints];
        chainEntity.checkpoints = archivedCheckpoints;
    }
    return chainEntity;
}

@end
