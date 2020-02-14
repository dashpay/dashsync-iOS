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
    self.standardPort = chain.standardPort;
    self.type = chain.chainType;
    self.totalMasternodeCount = chain.totalMasternodeCount;
    self.totalGovernanceObjectsCount = chain.totalGovernanceObjectsCount;
    return self;
}

- (DSChain *)chain {
    __block DSChainType type;
    __block uint32_t port;
    __block uint32_t dapiJRPCPort;
    __block uint32_t dapiGRPCPort;
    __block NSString * devnetIdentifier;
    __block NSData * data;
    __block uint32_t totalMasternodeCount;
    __block uint32_t totalGovernanceObjectsCount;
    __block UInt256 baseBlockHash;
    __block UInt256 dpnsContractID;
    [self.managedObjectContext performBlockAndWait:^{
        port = self.standardPort;
        dapiJRPCPort = self.standardDapiJRPCPort;
        dapiGRPCPort = self.standardDapiGRPCPort;
        type = self.type;
        devnetIdentifier = self.devnetIdentifier;
        data = self.checkpoints;
        totalMasternodeCount = self.totalMasternodeCount;
        totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        baseBlockHash = self.baseBlockHash.UInt256;
        dpnsContractID = self.dpnsContractID.UInt256;
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
            return [DSChain setUpDevnetWithIdentifier:devnetIdentifier withCheckpoints:checkpointArray withDefaultPort:port withDefaultDapiJRPCPort:dapiJRPCPort withDefaultDapiGRPCPort:dapiGRPCPort dpnsContractID:dpnsContractID];
        }
    }
    return nil;
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
    if (type == DSChainType_MainNet) {
        chainEntity.standardPort = MAINNET_STANDARD_PORT;
        chainEntity.standardDapiJRPCPort = MAINNET_DAPI_JRPC_STANDARD_PORT;
        chainEntity.standardDapiGRPCPort = MAINNET_DAPI_GRPC_STANDARD_PORT;
    } else if (type == DSChainType_TestNet) {
        chainEntity.standardPort = TESTNET_STANDARD_PORT;
        chainEntity.standardDapiJRPCPort = TESTNET_DAPI_JRPC_STANDARD_PORT;
        chainEntity.standardDapiGRPCPort = TESTNET_DAPI_GRPC_STANDARD_PORT;
    } else {
        chainEntity.standardPort = DEVNET_STANDARD_PORT;
        chainEntity.standardDapiJRPCPort = DEVNET_DAPI_JRPC_STANDARD_PORT;
        chainEntity.standardDapiGRPCPort = DEVNET_DAPI_GRPC_STANDARD_PORT;
    }
    return chainEntity;
}

@end
