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

#import "DPSTPacket.h"

#import "DPErrors.h"
#import "DPSTPacket+HashCalculations.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPSTPacket ()

@property (strong, nonatomic) id<DPMerkleRootOperation> merkleRootOperation;
@property (copy, nonatomic) NSArray<DPContract *> *contracts;
@property (strong, nonatomic) NSMutableArray<DPDocument *> *mutableDocuments;

@end

@implementation DPSTPacket

- (instancetype)initWithContractId:(NSString *)contractId
               merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation {
    NSParameterAssert(contractId);
    NSParameterAssert(merkleRootOperation);

    self = [super init];
    if (self) {
        _merkleRootOperation = merkleRootOperation;
        _contractId = [contractId copy];
        _contracts = @[];
        _mutableDocuments = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithContract:(DPContract *)contract
             merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation {
    NSParameterAssert(contract);
    NSParameterAssert(merkleRootOperation);

    self = [self initWithContractId:contract.identifier merkleRootOperation:merkleRootOperation];
    if (self) {
        _contracts = @[ contract ];
    }
    return self;
}

- (instancetype)initWithContractId:(NSString *)contractId
                         documents:(NSArray<DPDocument *> *)documents
               merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation {
    NSParameterAssert(contractId);
    NSParameterAssert(documents);
    NSParameterAssert(merkleRootOperation);

    self = [self initWithContractId:contractId merkleRootOperation:merkleRootOperation];
    if (self) {
        _mutableDocuments = [documents mutableCopy];
    }
    return self;
}

- (NSString *)itemsMerkleRoot {
    return [self dp_calculateItemsMerkleRootWithOperation:self.merkleRootOperation];
}

- (NSString *)itemsHash {
    return [self dp_calculateItemsHash];
}

- (NSArray<DPDocument *> *)documents {
    return [self.mutableDocuments copy];
}

- (void)setContract:(DPContract *)contract error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(contract);
    if (!contract) {
        return;
    }

    if (self.documents.count > 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_ContractAndDocumentsNotAllowedSamePacket
                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
        }

        return;
    }

    self.contracts = @[ contract ];
    [self resetSerializedValues];
}

- (void)setDocuments:(NSArray<DPDocument *> *)documents error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(documents);
    if (self.contracts.count > 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_ContractAndDocumentsNotAllowedSamePacket
                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
        }

        return;
    }

    self.mutableDocuments = [documents mutableCopy];
    [self resetSerializedValues];
}

- (void)addDocument:(DPDocument *)document error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(document);
    if (self.contracts.count > 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_ContractAndDocumentsNotAllowedSamePacket
                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
        }

        return;
    }

    [self.mutableDocuments addObject:document];
    [self resetSerializedValues];
}

- (void)resetSerializedValues {
    [super resetSerializedValues];
    _json = nil;
}

#pragma mark - DPPSerializableObject

@synthesize json = _json;

- (DPMutableJSONObject *)json {
    if (_json == nil) {
        DPMutableJSONObject *json = [[DPMutableJSONObject alloc] init];
        json[@"contractId"] = self.contractId;
        json[@"itemsMerkleRoot"] = self.itemsMerkleRoot;
        json[@"itemsHash"] = self.itemsHash;
        NSMutableArray<DPJSONObject *> *jsonContracts = [NSMutableArray array];
        for (DPContract *contract in self.contracts) {
            [jsonContracts addObject:contract.json];
        }
        json[@"contracts"] = jsonContracts;
        NSMutableArray<DPJSONObject *> *jsonDocuments = [NSMutableArray array];
        for (DPDocument *document in self.documents) {
            [jsonDocuments addObject:document.json];
        }
        json[@"documents"] = jsonDocuments;
        _json = json;
    }
    return _json;
}

@end

NS_ASSUME_NONNULL_END
