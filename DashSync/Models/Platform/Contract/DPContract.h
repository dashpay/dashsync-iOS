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

#import "DPBase58DataEncoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPContract : DPBaseObject

@property (readonly, copy, nonatomic) NSString *identifier;
@property (readonly, copy, nonatomic) NSString *jsonSchemaId;

@property (assign, nonatomic) NSInteger version;
@property (copy, nonatomic) NSString *contractID;
@property (copy, nonatomic) NSString *jsonMetaSchema;
@property (copy, nonatomic) NSDictionary<NSString *, DPJSONObject *> *documents;
@property (copy, nonatomic) NSDictionary<NSString *, DPJSONObject *> *definitions;

- (instancetype)initWithContractID:(NSString *)contractID
                   documents:(NSDictionary<NSString *, DPJSONObject *> *)documents
           base58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isDocumentDefinedForType:(NSString *)type;
- (void)setDocumentSchema:(DPJSONObject *)schema forType:(NSString *)type;
- (nullable DPJSONObject *)documentSchemaForType:(NSString *)type;

- (nullable NSDictionary<NSString *, NSString *> *)documentSchemaRefForType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
