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
#import "DSBlock.h"
#import "NSCoder+Dash.h"
#import "NSData+DSHash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"

@interface DSCheckpoint ()

@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 blockHash;
@property (nonatomic, assign) uint32_t timestamp;
@property (nonatomic, assign) uint32_t target;
@property (nonatomic, strong) NSString *masternodeListName;
@property (nonatomic, assign) UInt256 merkleRoot;
@property (nonatomic, assign) UInt256 chainWork;

@end

@implementation DSCheckpoint

#pragma mark NSCoding

#define kHeightKey @"Height"
#define kCheckpointHashKey @"CheckpointHash"
#define kTimestampKey @"Timestamp"
#define kTargetKey @"Target"
#define kChainWorkKey @"ChainWork"

+ (DSCheckpoint *)genesisDevnetCheckpoint {
    DSCheckpoint *checkpoint = [DSCheckpoint new];
    checkpoint.blockHash = [NSString stringWithCString:"000008ca1832a4baf228eb1553c03d3a2c8e02399550dd6ea8d65cec3ef23d2e" encoding:NSUTF8StringEncoding].hexToData.reverse.UInt256;
    checkpoint.height = 0;
    checkpoint.timestamp = 1417713337;
    checkpoint.target = 0x207fffffu;
    checkpoint.chainWork = @"0200000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    return checkpoint;
}

- (instancetype)initWithHeight:(uint32_t)height blockHash:(UInt256)blockHash timestamp:(uint32_t)timestamp target:(uint32_t)target merkleRoot:(UInt256)merkleRoot chainWork:(UInt256)chainWork masternodeListName:(NSString *_Nullable)masternodeListName {
    if (!(self = [super init])) return nil;

    self.blockHash = blockHash;
    self.height = height;
    self.timestamp = timestamp;
    self.target = target;
    self.merkleRoot = merkleRoot;
    self.chainWork = chainWork;
    self.masternodeListName = masternodeListName;

    return self;
}

- (instancetype)initWithData:(NSData *)data {
    return [self initWithData:data atOffset:0 finalOffset:0];
}

- (instancetype)initWithData:(NSData *)data atOffset:(uint32_t)offset finalOffset:(uint32_t *)finalOffset {
    if (!(self = [super init])) return nil;
    uint32_t off = offset;
    uint8_t parameters = [data UInt8AtOffset:0];
    off++;
    self.height = [data UInt32AtOffset:off];
    off += 4;
    self.blockHash = [data UInt256AtOffset:off];
    off += 32;
    self.timestamp = [data UInt32AtOffset:off];
    off += 4;
    self.target = [data UInt32AtOffset:off];
    off += 4;
    uint8_t chainWorkSize = parameters >> 4;
    UInt256 chainWork = UINT256_ZERO;
    for (uint32_t i = 0; i < chainWorkSize; i++) {
        uint32_t chainWorkSection = [data UInt32AtOffset:off];
        chainWork.u32[i] = chainWorkSection;
        off += 4;
    }
    self.chainWork = chainWork;
    if (parameters & DSCheckpointParameter_MerkleRoot) {
        self.merkleRoot = [data UInt256AtOffset:off];
        off += 32;
    }
    if (parameters & DSCheckpointParameter_MasternodeList) {
        NSNumber *l;
        self.masternodeListName = [data stringAtOffset:off length:&l];
        off += l.unsignedIntegerValue;
    }
    if (finalOffset) {
        *finalOffset = off;
    }
    return self;
}

+ (instancetype)checkpointForHeight:(uint32_t)height blockHash:(UInt256)blockHash timestamp:(uint32_t)timestamp target:(uint32_t)target merkleRoot:(UInt256)merkleRoot chainWork:(UInt256)chainWork masternodeListName:(NSString *_Nullable)masternodeListName {
    return [[self alloc] initWithHeight:height blockHash:blockHash timestamp:timestamp target:target merkleRoot:merkleRoot chainWork:chainWork masternodeListName:masternodeListName];
}

+ (instancetype)checkpointFromBlock:(DSBlock *)block options:(uint8_t)options {
    NSAssert(block.height != BLOCK_UNKNOWN_HEIGHT, @"Block height must be known");
    return [[self alloc] initWithHeight:block.height blockHash:block.blockHash timestamp:block.timestamp target:block.target merkleRoot:(options & DSCheckpointOptions_SaveMerkleRoot) ? block.merkleRoot : UINT256_ZERO chainWork:block.chainWork masternodeListName:nil];
}

- (uint8_t)chainWorkSize {
    uint8_t chainWorkSize = 8;
    for (uint8_t i = 7; i != UINT8_MAX; i--) {
        if (self.chainWork.u32[i] == 0) {
            chainWorkSize--;
        }
    }
    return chainWorkSize;
}

- (uint8_t)parameters {
    uint8_t parameters = 0;
    if (uint256_is_not_zero(self.merkleRoot)) parameters |= DSCheckpointParameter_MerkleRoot;
    if (self.masternodeListName) parameters |= DSCheckpointParameter_MasternodeList;
    parameters |= DSCheckpointParameter_ChainWorkSize * [self chainWorkSize];
    return parameters;
}

// This is the old protocol version used for creating checkpoints
// Now when storing list diff we add version at the end of masternode list name like this: MNT530000__70228
- (uint32_t)protocolVersion {
    uint32_t protocolVersion = DEFAULT_CHECKPOINT_PROTOCOL_VERSION;
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"__(\\d+)"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    NSTextCheckingResult *match = [regex
                                   firstMatchInString:self.masternodeListName
                                   options:0
                                   range:NSMakeRange(0, [self.masternodeListName length])];
    if (match) {
        NSString *numberString = [self.masternodeListName substringWithRange:[match rangeAtIndex:1]];
        if (numberString) {
            protocolVersion = (uint32_t)[numberString integerValue];
        }
    }
    return protocolVersion;
}


- (NSData *)serialize {
    NSMutableData *mData = [NSMutableData data];
    [mData appendUInt8:[self parameters]];
    [mData appendUInt32:self.height];
    [mData appendUInt256:self.blockHash];
    [mData appendUInt32:self.timestamp];
    [mData appendUInt32:self.target];
    for (uint32_t i = 0; i < [self chainWorkSize]; i++) {
        [mData appendUInt32:self.chainWork.u32[0]];
    }
    if (uint256_is_not_zero(self.merkleRoot)) {
        [mData appendUInt256:self.merkleRoot];
    }
    if (self.masternodeListName) {
        [mData appendString:self.masternodeListName];
    }
    return [mData copy];
}

- (DSBlock *)blockForChain:(DSChain *)chain {
    return [[DSBlock alloc] initWithCheckpoint:self onChain:chain];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)initWithCoder:(NSCoder *)decoder {
    UInt256 checkpointHash = [decoder decodeUInt256ForKey:kCheckpointHashKey];
    uint32_t height = [decoder decodeInt32ForKey:kHeightKey];
    uint32_t timestamp = [decoder decodeInt32ForKey:kTimestampKey];
    uint32_t target = [decoder decodeInt32ForKey:kTargetKey];
    UInt256 chainWork = [decoder decodeUInt256ForKey:kChainWorkKey];
    if (uint256_is_zero(chainWork)) {
        if (height == 0) {
            chainWork = @"0000000000000000000000000000000000000000000000000000000000000002".hexToData.reverse.UInt256;
        } else if (height == 1) {
            chainWork = @"0000000000000000000000000000000000000000000000000000000000000004".hexToData.reverse.UInt256;
        } else {
            NSAssert(FALSE, @"We should never reach this spot");
        }
    }
    return [self initWithHeight:height blockHash:checkpointHash timestamp:timestamp target:target merkleRoot:UINT256_ZERO chainWork:chainWork masternodeListName:nil];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeUInt256:self.blockHash forKey:kCheckpointHashKey];
    [aCoder encodeInt32:self.height forKey:kHeightKey];
    [aCoder encodeInt32:self.timestamp forKey:kTimestampKey];
    [aCoder encodeInt32:self.target forKey:kTargetKey];
    [aCoder encodeUInt256:self.chainWork forKey:kChainWorkKey];
}

- (BOOL)isEqual:(id)object {
    return [[self serialize] isEqualToData:[object serialize]];
}

- (NSUInteger)hash {
    return [self serialize].SHA256_2.u64[0];
}

@end
