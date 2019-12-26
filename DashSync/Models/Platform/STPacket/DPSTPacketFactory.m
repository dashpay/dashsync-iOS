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

#import "DPSTPacketFactory.h"

#import "DPContractFactory+CreateContract.h"
#import "DPSerializeUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPSTPacketFactory ()

@property (strong, nonatomic) id<DPMerkleRootOperation> merkleRootOperation;
@property (strong, nonatomic) id<DPBase58DataEncoder> base58DataEncoder;

@end

@implementation DPSTPacketFactory

- (instancetype)initWithMerkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation
                          base58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder {
    NSParameterAssert(merkleRootOperation);
    NSParameterAssert(base58DataEncoder);

    self = [super init];
    if (self) {
        _merkleRootOperation = merkleRootOperation;
        _base58DataEncoder = base58DataEncoder;
    }
    return self;
}

#pragma mark - DPSTPacketFactory

- (DPSTPacket *)packetWithContract:(DPContract *)contract {
    NSParameterAssert(contract);

    DPSTPacket *packet = [[DPSTPacket alloc] initWithContract:contract
                                          merkleRootOperation:self.merkleRootOperation];

    return packet;
}

- (DPSTPacket *)packetWithContractId:(NSString *)contractId
                           documents:(NSArray<DPDocument *> *)documents {
    NSParameterAssert(contractId);
    NSParameterAssert(documents);

    DPSTPacket *packet = [[DPSTPacket alloc] initWithContractId:contractId
                                                      documents:documents
                                            merkleRootOperation:self.merkleRootOperation];

    return packet;
}

- (nullable DPSTPacket *)packetFromRawPacket:(DPJSONObject *)rawPacket
                                       error:(NSError *_Nullable __autoreleasing *)error {
    return [self packetFromRawPacket:rawPacket skipValidation:NO error:error];
}

- (nullable DPSTPacket *)packetFromRawPacket:(DPJSONObject *)rawPacket
                              skipValidation:(BOOL)skipValidation
                                       error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(rawPacket);

    // TODO: validate rawPacket

    NSString *contractId = rawPacket[@"contractId"];
    NSParameterAssert(contractId);

    DPSTPacket *packet = [[DPSTPacket alloc] initWithContractId:contractId
                                            merkleRootOperation:self.merkleRootOperation];

    NSArray<DPJSONObject *> *rawContracts = rawPacket[@"contracts"];
    if (rawContracts.count > 0) {
        DPJSONObject *rawContract = rawContracts.firstObject;
        DPContract *contract = [DPContractFactory dp_contractFromRawContract:rawContract
                                                           base58DataEncoder:self.base58DataEncoder];
        [packet setContract:contract error:error];
        if (*error != nil) {
            return nil;
        }
    }

    NSArray<DPJSONObject *> *rawDocuments = rawPacket[@"documents"];
    if (rawDocuments.count > 0) {
        NSMutableArray<DPDocument *> *documents = [NSMutableArray array];
        for (DPJSONObject *rawDocument in rawDocuments) {
            DPDocument *document = [[DPDocument alloc] initWithRawDocument:rawDocument
                                                         base58DataEncoder:self.base58DataEncoder];
            [documents addObject:document];
        }
        [packet setDocuments:documents error:error];
        if (*error != nil) {
            return nil;
        }
    }

    return packet;
}

- (nullable DPSTPacket *)packetFromSerialized:(NSData *)data
                                        error:(NSError *_Nullable __autoreleasing *)error {
    return [self packetFromSerialized:data skipValidation:NO error:error];
}

- (nullable DPSTPacket *)packetFromSerialized:(NSData *)data
                               skipValidation:(BOOL)skipValidation
                                        error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(data);

    DPJSONObject *rawPacket = [DPSerializeUtils decodeSerializedObject:data
                                                                 error:error];
    if (!rawPacket) {
        return nil;
    }

    return [self packetFromRawPacket:rawPacket
                      skipValidation:skipValidation
                               error:error];
}


@end

NS_ASSUME_NONNULL_END
