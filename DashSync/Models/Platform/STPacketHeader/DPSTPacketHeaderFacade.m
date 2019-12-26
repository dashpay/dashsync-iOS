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

#import "DPSTPacketHeaderFacade.h"

#import "DPSTPacketHeaderFactory.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPSTPacketHeaderFacade ()

@property (strong, nonatomic) DPSTPacketHeaderFactory *factory;

@end

@implementation DPSTPacketHeaderFacade

- (instancetype)init {
    self = [super init];
    if (self) {
        _factory = [[DPSTPacketHeaderFactory alloc] init];
    }
    return self;
}

#pragma mark - DPSTPacketHeaderFactory

- (DPSTPacketHeader *)packetHeaderWithContractId:(NSString *)contractId
                                 itemsMerkleRoot:(NSString *)itemsMerkleRoot
                                       itemsHash:(NSString *)itemsHash {
    return [self.factory packetHeaderWithContractId:contractId
                                    itemsMerkleRoot:itemsMerkleRoot
                                          itemsHash:itemsHash];
}

- (nullable DPSTPacketHeader *)packetHeaderFromRawPacketHeader:(DPJSONObject *)rawPacketHeader
                                                         error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory packetHeaderFromRawPacketHeader:rawPacketHeader error:error];
}

- (nullable DPSTPacketHeader *)packetHeaderFromRawPacketHeader:(DPJSONObject *)rawPacketHeader
                                                skipValidation:(BOOL)skipValidation
                                                         error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory packetHeaderFromRawPacketHeader:rawPacketHeader skipValidation:skipValidation error:error];
}

- (nullable DPSTPacketHeader *)packetHeaderFromSerialized:(NSData *)data
                                                    error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory packetHeaderFromSerialized:data error:error];
}

- (nullable DPSTPacketHeader *)packetHeaderFromSerialized:(NSData *)data
                                           skipValidation:(BOOL)skipValidation
                                                    error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory packetHeaderFromSerialized:data skipValidation:skipValidation error:error];
}

@end

NS_ASSUME_NONNULL_END
