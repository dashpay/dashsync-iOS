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

#import "NSData+Bitcoin.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPDocument ()

@property (copy, nonatomic) NSString *tableName;
@property (copy, nonatomic) NSString *userId;
@property (copy, nonatomic) NSString *contractId;
@property (copy, nonatomic) NSString *entropy;
@property (copy, nonatomic) NSNumber *currentRevision;
@property (strong, nonatomic) DPDocumentState *currentRegisteredDocumentState;
@property (strong, nonatomic) DPDocumentState *currentLocalDocumentState;
@property (strong, nonatomic) NSMutableArray<DPDocumentState *>* documentStates;

@end

@implementation DPDocument

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(NSString*)userId onContractWithId:(NSString*)contractId onTableWithName:(NSString*)tableName usingEntropy:(NSString*)entropy {
    NSParameterAssert(dataDictionary);
    NSParameterAssert(userId);
    NSParameterAssert(contractId);
    NSParameterAssert(tableName);
    NSParameterAssert(entropy);

    self = [super init];
    if (self) {
        
        self.tableName = tableName;
        self.userId = userId;
        self.contractId = contractId;
        self.entropy = entropy;
        
        self.currentRevision = @1;
        self.currentLocalDocumentState = [DPDocumentState documentStateWithDataDictionary:dataDictionary];
        self.documentStates = [NSMutableArray arrayWithObject:self.currentLocalDocumentState];
    }

    return self;
}

- (nullable DPDocument *)documentWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(NSString*)userId onContractWithId:(NSString*)contractId inTable:(NSString*)table withEntropy:(NSString*)entropy {
    return [[DPDocument alloc] initWithDataDictionary:dataDictionary createdByUserWithId:userId onContractWithId:contractId onTableWithName:table usingEntropy:entropy];
}

- (void)addStateForChangingData:(DSStringValueDictionary *)dataDictionary {
    DPDocumentState * lastState = [self.documentStates lastObject];
    
    DSMutableStringValueDictionary * stateDataDictionary = [lastState.dataChangeDictionary mutableCopy];
    [stateDataDictionary addEntriesFromDictionary:dataDictionary];
    
    self.currentLocalDocumentState = [DPDocumentState documentStateWithDataDictionary:stateDataDictionary ofType:DPDocumentStateType_Update];
    
    [self.documentStates addObject:self.currentLocalDocumentState];
}

#pragma mark - DPPSerializableObject

- (DSMutableStringValueDictionary *)objectDictionary {
    DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
    json[@"$type"] = self.tableName;
    json[@"$contractId"] = self.contractId;
    json[@"$ownerId"] = self.userId;
    json[@"$entropy"] = self.entropy;
    json[@"$rev"] = self.currentRevision;
    [json addEntriesFromDictionary:self.currentLocalDocumentState.dataChangeDictionary];
    return json;
}

@end

NS_ASSUME_NONNULL_END
