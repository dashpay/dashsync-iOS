//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DPSTPacketHeaderFactory.h"
#import <TinyCborObjc/NSData+DSCborDecoding.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DPSTPacketHeaderFactory

#pragma mark - DPSTPacketHeaderFactory

- (DPSTPacketHeader *)packetHeaderWithContractId:(NSString *)contractId
                                 itemsMerkleRoot:(NSString *)itemsMerkleRoot
                                       itemsHash:(NSString *)itemsHash {
    NSParameterAssert(contractId);
    NSParameterAssert(itemsMerkleRoot);
    NSParameterAssert(itemsHash);

    DPSTPacketHeader *object = [[DPSTPacketHeader alloc] initWithContractId:contractId
                                                            itemsMerkleRoot:itemsMerkleRoot
                                                                  itemsHash:itemsHash];

    return object;
}

- (nullable DPSTPacketHeader *)packetHeaderFromRawPacketHeader:(DSStringValueDictionary *)rawPacketHeader
                                                         error:(NSError *_Nullable __autoreleasing *)error {
    return [self packetHeaderFromRawPacketHeader:rawPacketHeader skipValidation:NO error:error];
}

- (nullable DPSTPacketHeader *)packetHeaderFromRawPacketHeader:(DSStringValueDictionary *)rawPacketHeader
                                                skipValidation:(BOOL)skipValidation
                                                         error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(rawPacketHeader);

    // TODO: validate rawPacketHeader

    DPSTPacketHeader *object = [self packetHeaderWithContractId:rawPacketHeader[@"contractId"]
                                                itemsMerkleRoot:rawPacketHeader[@"itemsMerkleRoot"]
                                                      itemsHash:rawPacketHeader[@"itemsHash"]];

    return object;
}

- (nullable DPSTPacketHeader *)packetHeaderFromSerialized:(NSData *)data
                                                    error:(NSError *_Nullable __autoreleasing *)error {
    return [self packetHeaderFromSerialized:data skipValidation:NO error:error];
}

- (nullable DPSTPacketHeader *)packetHeaderFromSerialized:(NSData *)data
                                           skipValidation:(BOOL)skipValidation
                                                    error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(data);

    DSStringValueDictionary *rawPacketHeader = [data ds_decodeCborError:error];
    
    if (!rawPacketHeader) {
        return nil;
    }

    return [self packetHeaderFromRawPacketHeader:rawPacketHeader
                                  skipValidation:skipValidation
                                           error:error];
}

@end

NS_ASSUME_NONNULL_END
