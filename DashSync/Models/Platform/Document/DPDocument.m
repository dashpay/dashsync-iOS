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

#import "DPErrors.h"
#import "DPSerializeUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPDocument ()

@property (strong, nonatomic) id<DPBase58DataEncoder> base58DataEncoder;
@property (assign, nonatomic) DPDocumentAction action;
@property (copy, nonatomic) DPJSONObject *data;

@end

@implementation DPDocument

@synthesize identifier = _identifier;

- (instancetype)initWithRawDocument:(DPJSONObject *)rawDocument
                  base58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder {
    NSParameterAssert(rawDocument);
    NSParameterAssert(base58DataEncoder);

    self = [super init];
    if (self) {
        _base58DataEncoder = base58DataEncoder;

        DPMutableJSONObject *mutableRawObject = [rawDocument mutableCopy];

        NSString *type = mutableRawObject[@"$type"];
        NSParameterAssert(type);
        if (type) {
            _type = [type copy];
            [mutableRawObject removeObjectForKey:@"$type"];
        }
        NSString *scope = mutableRawObject[@"$scope"];
        NSParameterAssert(scope);
        if (scope) {
            _scope = [scope copy];
            [mutableRawObject removeObjectForKey:@"$scope"];
        }
        NSString *scopeId = mutableRawObject[@"$scopeId"];
        NSParameterAssert(scopeId);
        if (scopeId) {
            _scopeId = [scopeId copy];
            [mutableRawObject removeObjectForKey:@"$scopeId"];
        }
        NSNumber *action = mutableRawObject[@"$action"];
        NSParameterAssert(action);
        if (action) {
            _action = action.unsignedIntegerValue;
            [mutableRawObject removeObjectForKey:@"$action"];
        }
        NSNumber *rev = mutableRawObject[@"$rev"];
        NSParameterAssert(rev);
        if (rev) {
            _revision = rev;
            [mutableRawObject removeObjectForKey:@"$rev"];
        }

        _data = [mutableRawObject copy];
    }

    return self;
}

- (NSString *)identifier {
    if (_identifier == nil) {
        NSString *identifierString = [self.scope stringByAppendingString:self.scopeId];
        NSData *identifierStringData = [identifierString dataUsingEncoding:NSUTF8StringEncoding];
        NSData *identifierHashData = [DPSerializeUtils hashDataOfData:identifierStringData];
        _identifier = [self.base58DataEncoder base58WithData:identifierHashData];
    }
    return _identifier;
}

- (void)setAction:(DPDocumentAction)action error:(NSError *_Nullable __autoreleasing *)error {
    if (action == DPDocumentAction_Delete && self.data.count != 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_DataIsNotAllowedWithActionDelete
                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
        }

        return;
    }

    _action = action;
    [self resetSerializedValues];
}

- (void)setData:(DPJSONObject *)data error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(data);

    if (self.action == DPDocumentAction_Delete && data.count != 0) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_DataIsNotAllowedWithActionDelete
                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
        }

        return;
    }

    _data = data;
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
        json[@"$type"] = self.type;
        json[@"$scope"] = self.scope;
        json[@"$scopeId"] = self.scopeId;
        json[@"$action"] = @(self.action);
        json[@"$rev"] = self.revision;
        [json addEntriesFromDictionary:self.data];
        _json = json;
    }
    return _json;
}

@end

NS_ASSUME_NONNULL_END
