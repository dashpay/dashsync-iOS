//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSCheckpoint.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"
#import "NSCoder+Dash.h"
#import "DSBlock.h"

@interface DSCheckpoint()

@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 checkpointHash;
@property (nonatomic, assign) uint32_t timestamp;
@property (nonatomic, assign) uint32_t target;
@property (nonatomic, strong) NSString * masternodeListName;
@property (nonatomic, assign) UInt256 merkleRoot;
@property (nonatomic, assign) UInt256 chainWork;


@end

@implementation DSCheckpoint

+(DSCheckpoint*)genesisDevnetCheckpoint {
    DSCheckpoint * checkpoint = [DSCheckpoint new];
    checkpoint.checkpointHash = [NSString stringWithCString:"000008ca1832a4baf228eb1553c03d3a2c8e02399550dd6ea8d65cec3ef23d2e" encoding:NSUTF8StringEncoding].hexToData.reverse.UInt256;
    checkpoint.height = 0;
    checkpoint.timestamp = 1417713337;
    checkpoint.target = 0x207fffffu;
    checkpoint.chainWork = @"0200000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    return checkpoint;
}

-(instancetype)initWithHeight:(uint32_t)height blockHash:(UInt256)blockHash timestamp:(uint32_t)timestamp target:(uint32_t)target merkleRoot:(UInt256)merkleRoot chainWork:(UInt256)chainWork masternodeListName:(NSString* _Nullable)masternodeListName {
    if (! (self = [super init])) return nil;
    
    self.checkpointHash = blockHash;
    self.height = height;
    self.timestamp = timestamp;
    self.target = target;
    self.merkleRoot = merkleRoot;
    self.chainWork = chainWork;
    self.masternodeListName = masternodeListName;
    
    return self;
}

+ (instancetype)checkpointForHeight:(uint32_t)height blockHash:(UInt256)blockHash timestamp:(uint32_t)timestamp target:(uint32_t)target merkleRoot:(UInt256)merkleRoot chainWork:(UInt256)chainWork masternodeListName:(NSString* _Nullable)masternodeListName {
    return [[self alloc] initWithHeight:height blockHash:blockHash timestamp:timestamp target:target merkleRoot:merkleRoot chainWork:chainWork masternodeListName:masternodeListName];
}

//- (id)initWithCoder:(NSCoder *)decoder {
//    UInt256 checkpointHash = [decoder decodeUInt256ForKey:kCheckpointHashKey];
//    uint32_t height = [decoder decodeInt32ForKey:kHeightKey];
//    uint32_t timestamp = [decoder decodeInt32ForKey:kTimestampKey];
//    uint32_t target = [decoder decodeInt32ForKey:kTargetKey];
//    return [self initWithHash:checkpointHash height:height timestamp:timestamp target:target];
//}

-(DSBlock*)blockForChain:(DSChain*)chain {
    return [[DSBlock alloc] initWithCheckpoint:self onChain:chain];
}

//-(void)encodeWithCoder:(NSCoder *)aCoder {
//    [aCoder encodeUInt256:self.checkpointHash forKey:kCheckpointHashKey];
//    [aCoder encodeInt32:self.height forKey:kHeightKey];
//    [aCoder encodeInt32:self.timestamp forKey:kTimestampKey];
//    [aCoder encodeInt32:self.target forKey:kTargetKey];
//}

@end

