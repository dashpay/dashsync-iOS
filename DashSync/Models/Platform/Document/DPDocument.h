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

#import "DPBaseObject.h"

NS_ASSUME_NONNULL_BEGIN

@class DPDocumentState;

@interface DPDocument : NSObject

@property (readonly, copy, nonatomic) NSString *tableName;
@property (readonly, copy, nonatomic) NSString *contractId;
@property (readonly, copy, nonatomic) NSString *userId;
@property (readonly, copy, nonatomic) NSString *entropy;
@property (readonly, nonatomic) DPDocumentState *currentRegisteredDocumentState;
@property (readonly, nonatomic) DPDocumentState *currentLocalDocumentState;
@property (readonly, copy, nonatomic) NSNumber *currentRegisteredRevision;
@property (readonly, copy, nonatomic) NSNumber *currentLocalRevision;
@property (readonly, copy, nonatomic) DSStringValueDictionary *objectDictionary;

- (instancetype)initWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(NSString*)userId onContractWithId:(NSString*)contractId onTableWithName:(NSString*)table usingEntropy:(NSString*)entropy;

- (instancetype)init NS_UNAVAILABLE;

- (void)addStateForChangingData:(DSStringValueDictionary *)dataDictionary;

- (nullable DPDocument *)documentWithDataDictionary:(DSStringValueDictionary *)dataDictionary createdByUserWithId:(NSString*)userId onContractWithId:(NSString*)contractId inTable:(NSString*)table withEntropy:(NSString*)entropy;

@end

NS_ASSUME_NONNULL_END
