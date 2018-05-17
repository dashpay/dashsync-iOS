//
//  DSChainEntity+CoreDataClass.m
//  DashSync
//
//  Created by Quantum Explorer on 05/05/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
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

#import "DSChainEntity+CoreDataClass.h"
#import "DSChainPeerManager.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "NSString+Dash.h"

@implementation DSChainEntity

- (instancetype)setAttributesFromChain:(DSChain *)chain {
    self.standardPort = @(chain.standardPort);
    self.type = @(chain.chainType);
    return self;
}

- (DSChain *)chain {
    __block DSChainType type;
    __block uint32_t port;
    __block UInt256 genisisHash;
    __block NSData * data;
    [self.managedObjectContext performBlockAndWait:^{
        port = (uint32_t)[self.standardPort unsignedLongValue];
        type = [self.type integerValue];
        genisisHash = *(UInt256 *)self.genesisBlockHash.hexToData.bytes;
        data = self.checkpoints;
        }];
    if (type == DSChainType_MainNet) {
        return [DSChain mainnet];
    } else if (type == DSChainType_TestNet) {
        return [DSChain testnet];
    } else if (type == DSChainType_DevNet) {
        if ([DSChain devnetWithGenesisHash:genisisHash]) {
            return [DSChain devnetWithGenesisHash:genisisHash];
        } else {
            NSArray * checkpointArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            return [DSChain createDevnetWithCheckpoints:checkpointArray onPort:port];
        }
    }
    return nil;
}

+ (DSChainEntity*)chainEntityForType:(DSChainType)type genisisBlock:(UInt256)genisisBlock {
    return [DSChainEntity objectsMatching:@"type = %@",type];
    //when I wake up I need to create this properly
}

@end
