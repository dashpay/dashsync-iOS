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

#import "DPContract.h"
#import "DPDocument.h"
#import "DPMerkleRootOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPSTPacket : DPBaseObject

@property (readonly, copy, nonatomic) NSString *contractId;
@property (readonly, copy, nonatomic) NSString *itemsMerkleRoot;
@property (readonly, copy, nonatomic) NSString *itemsHash;
@property (readonly, copy, nonatomic) NSArray<DPContract *> *contracts;
@property (readonly, copy, nonatomic) NSArray<DPDocument *> *documents;

- (instancetype)initWithContractId:(NSString *)contractId
               merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithContract:(DPContract *)contract
             merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation;

- (instancetype)initWithContractId:(NSString *)contractId
                         documents:(NSArray<DPDocument *> *)documents
               merkleRootOperation:(id<DPMerkleRootOperation>)merkleRootOperation;

- (instancetype)init NS_UNAVAILABLE;

- (void)setContract:(DPContract *)contract error:(NSError *_Nullable __autoreleasing *)error;
- (void)setDocuments:(NSArray<DPDocument *> *)documents error:(NSError *_Nullable __autoreleasing *)error;
- (void)addDocument:(DPDocument *)document error:(NSError *_Nullable __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
