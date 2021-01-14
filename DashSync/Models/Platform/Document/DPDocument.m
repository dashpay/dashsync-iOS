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

#import "DPDocument.h"
#import "DPDocumentState.h"

#import "DPErrors.h"

#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPDocument ()

@property (copy, nonatomic) NSString *tableName;
@property (assign, nonatomic) UInt256 ownerId;
@property (copy, nonatomic) NSString *base58OwnerIdString;
@property (assign, nonatomic) UInt256 contractId;
@property (copy, nonatomic) NSString *base58ContractIdString;
@property (assign, nonatomic) UInt256 documentId;
@property (copy, nonatomic) NSString *base58DocumentIdString;
@property (copy, nonatomic) NSData *entropy;
@property (copy, nonatomic) NSNumber *currentRevision;
@property (strong, nonatomic) DPDocumentState *currentRegisteredDocumentState;
@property (strong, nonatomic) DPDocumentState *currentLocalDocumentState;
@property (strong, nonatomic) NSMutableArray<DPDocumentState *> *documentStates;

@end

@implementation DPDocument

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(UInt256)ownerId onContractWithId:(UInt256)contractId onTableWithName:(NSString *)tableName {
    NSParameterAssert(dataDictionary);
    NSAssert(uint256_is_not_zero(ownerId), @"Owner Id must be set");
    NSAssert(uint256_is_not_zero(contractId), @"Contract Id must be set");
    NSParameterAssert(tableName);

    self = [super init];
    if (self) {
        self.tableName = tableName;
        self.ownerId = ownerId;
        self.contractId = contractId;

        self.currentRevision = @1;
        self.currentLocalDocumentState = [DPDocumentState documentStateWithDataDictionary:dataDictionary];
        self.documentStates = [NSMutableArray arrayWithObject:self.currentLocalDocumentState];
    }

    return self;
}

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(UInt256)ownerId onContractWithId:(UInt256)contractId onTableWithName:(NSString *)tableName usingEntropy:(NSData *)entropy {
    NSParameterAssert(entropy);
    NSAssert([entropy isKindOfClass:[NSData class]], @"Entropy must be binary");

    self = [self initWithDataDictionary:dataDictionary createdByUserWithId:ownerId onContractWithId:contractId onTableWithName:tableName];
    if (self) {
        self.entropy = entropy;
    }

    return self;
}

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(UInt256)ownerId onContractWithId:(UInt256)contractId onTableWithName:(NSString *)tableName usingDocumentId:(UInt256)documentId {
    NSAssert(uint256_is_not_zero(documentId), @"Document Id must be set");

    self = [self initWithDataDictionary:dataDictionary createdByUserWithId:ownerId onContractWithId:contractId onTableWithName:tableName];
    if (self) {
        self.documentId = documentId;
    }

    return self;
}

+ (nullable DPDocument *)documentWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(UInt256)ownerId onContractWithId:(UInt256)contractId onTableWithName:(NSString *)tableName usingEntropy:(NSData *)entropy {
    return [[DPDocument alloc] initWithDataDictionary:dataDictionary createdByUserWithId:ownerId onContractWithId:contractId onTableWithName:tableName usingEntropy:entropy];
}

+ (nullable DPDocument *)documentWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(UInt256)ownerId onContractWithId:(UInt256)contractId onTableWithName:(NSString *)tableName usingDocumentId:(UInt256)documentId {
    return [[DPDocument alloc] initWithDataDictionary:dataDictionary createdByUserWithId:ownerId onContractWithId:contractId onTableWithName:tableName usingDocumentId:documentId];
}

- (NSString *)base58OwnerIdString {
    if (!_base58OwnerIdString && uint256_is_not_zero(_ownerId)) {
        _base58OwnerIdString = uint256_base58(_ownerId);
    }
    return _base58OwnerIdString;
}

- (NSString *)base58ContractIdString {
    if (!_base58ContractIdString && uint256_is_not_zero(_contractId)) {
        _base58ContractIdString = uint256_base58(_contractId);
    }
    return _base58ContractIdString;
}

- (NSString *)base58DocumentIdString {
    if (!_base58DocumentIdString) {
        _base58DocumentIdString = uint256_base58(self.documentId);
    }
    return _base58DocumentIdString;
}


- (UInt256)documentId {
    if (uint256_is_zero(_documentId)) {
        NSAssert(uint256_is_not_zero(_ownerId), @"Owner needs to be set");
        NSAssert(uint256_is_not_zero(_contractId), @"Owner needs to be set");
        NSAssert(_tableName, @"Table name needs to be set");
        //NSAssert(!uint160_is_zero(self.entropy),@"Entropy needs to be set");
        NSMutableData *mData = [NSMutableData data];
        [mData appendUInt256:_contractId];
        [mData appendUInt256:_ownerId];
        [mData appendData:[_tableName dataUsingEncoding:NSUTF8StringEncoding]];
        [mData appendData:self.entropy];
        _documentId = [mData SHA256_2];
    }
    return _documentId;
}

- (void)addStateForChangingData:(DSStringValueDictionary *)dataDictionary {
    DPDocumentState *lastState = [self.documentStates lastObject];

    DSMutableStringValueDictionary *stateDataDictionary = [lastState.dataChangeDictionary mutableCopy];
    [stateDataDictionary addEntriesFromDictionary:dataDictionary];

    self.currentLocalDocumentState = [DPDocumentState documentStateWithDataDictionary:stateDataDictionary ofType:DPDocumentStateType_Update];

    [self.documentStates addObject:self.currentLocalDocumentState];
}

#pragma mark - DPPSerializableObject

- (DSMutableStringValueDictionary *)objectDictionary {
    DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
    json[@"$type"] = self.tableName;
    json[@"$dataContractId"] = uint256_data(self.contractId);
    json[@"$id"] = uint256_data(self.documentId);
    json[@"$action"] = @(self.currentLocalDocumentState.documentStateType >> 1);
    if (!(self.currentLocalDocumentState.documentStateType >> 1)) {
        json[@"$entropy"] = self.entropy;
    }
    [json addEntriesFromDictionary:self.currentLocalDocumentState.dataChangeDictionary];
    return json;
}

@end

NS_ASSUME_NONNULL_END
