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

#import "DPContract.h"

#import "DPSerializeUtils.h"

NS_ASSUME_NONNULL_BEGIN

static NSInteger const DEFAULT_VERSION = 1;
static NSString *const DEFAULT_SCHEMA = @"https://schema.dash.org/dpp-0-4-0/meta/contract";
static NSString *const DPCONTRACT_SCHEMA_ID = @"contract";

@interface DPContract ()

@property (strong, nonatomic) id<DPBase58DataEncoder> base58DataEncoder;
@property (strong, nonatomic) NSMutableDictionary<NSString *, DPJSONObject *> *mutableDocuments;

@end

@implementation DPContract

- (instancetype)initWithContractId:(NSString *)contractId
                   documents:(NSDictionary<NSString *, DPJSONObject *> *)documents
           base58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder {
    NSParameterAssert(contractId);
    NSParameterAssert(documents);
    NSParameterAssert(base58DataEncoder);

    self = [super init];
    if (self) {
        _base58DataEncoder = base58DataEncoder;
        _version = DEFAULT_VERSION;
        _jsonMetaSchema = DEFAULT_SCHEMA;
        _mutableDocuments = [documents mutableCopy];
        _definitions = @{};
    }
    return self;
}

- (NSString *)identifier {
    NSData *serializedData = [DPSerializeUtils hashDataOfData:self.serialized];
    return [self.base58DataEncoder base58WithData:serializedData];
}

- (NSString *)jsonSchemaId {
    return DPCONTRACT_SCHEMA_ID;
}

- (void)setVersion:(NSInteger)version {
    _version = version;
    [self resetSerializedValues];
}

- (void)setJsonMetaSchema:(NSString *)jsonMetaSchema {
    _jsonMetaSchema = [jsonMetaSchema copy];
    [self resetSerializedValues];
}

- (NSDictionary<NSString *, DPJSONObject *> *)documents {
    return [self.mutableDocuments copy];
}

- (void)setDocuments:(NSDictionary<NSString *, DPJSONObject *> *)documents {
    _mutableDocuments = [documents mutableCopy];
    [self resetSerializedValues];
}

- (void)setDefinitions:(NSDictionary<NSString *, DPJSONObject *> *)definitions {
    _definitions = [definitions copy];
    [self resetSerializedValues];
}

- (BOOL)isDocumentDefinedForType:(NSString *)type {
    NSParameterAssert(type);
    if (!type) {
        return NO;
    }

    BOOL isDefined = self.mutableDocuments[type] != nil;

    return isDefined;
}

- (void)setDocumentSchema:(DPJSONObject *)schema forType:(NSString *)type {
    NSParameterAssert(schema);
    NSParameterAssert(type);
    if (!schema || !type) {
        return;
    }

    self.mutableDocuments[type] = schema;
}

- (nullable DPJSONObject *)documentSchemaForType:(NSString *)type {
    NSParameterAssert(type);
    if (!type) {
        return nil;
    }

    return self.mutableDocuments[type];
}

- (nullable NSDictionary<NSString *, NSString *> *)documentSchemaRefForType:(NSString *)type {
    NSParameterAssert(type);
    if (!type) {
        return nil;
    }

    if (![self isDocumentDefinedForType:type]) {
        return nil;
    }

    NSString *refValue = [NSString stringWithFormat:@"%@#/documents/%@",
                                                    self.jsonSchemaId, type];
    NSDictionary<NSString *, NSString *> *dpObjectSchemaRef = @{ @"$ref" : refValue };

    return dpObjectSchemaRef;
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
        json[@"$schema"] = self.jsonMetaSchema;
        json[@"version"] = @(self.version);
        json[@"documents"] = self.documents;
        if (self.definitions.count > 0) {
            json[@"definitions"] = self.definitions;
        }
        _json = json;
    }
    return _json;
}

@end

NS_ASSUME_NONNULL_END
