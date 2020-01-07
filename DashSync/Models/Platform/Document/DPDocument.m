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

#import "NSData+Bitcoin.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPDocument ()

@property (copy, nonatomic) DSStringValueDictionary *data;

@end

@implementation DPDocument

//@synthesize identifier = _identifier;

- (instancetype)initWithRawDocument:(DSStringValueDictionary *)rawDocument {
    NSParameterAssert(rawDocument);

    self = [super init];
    if (self) {

        DSMutableStringValueDictionary *mutableRawObject = [rawDocument mutableCopy];

        NSString *type = mutableRawObject[@"$type"];
        NSParameterAssert(type);
        if (type) {
            _type = [type copy];
            [mutableRawObject removeObjectForKey:@"$type"];
        }
        NSString *contractId = mutableRawObject[@"$contractId"];
        NSParameterAssert(contractId);
        if (contractId) {
            _contractId = [contractId copy];
            [mutableRawObject removeObjectForKey:@"$contractId"];
        }
        NSString *userId = mutableRawObject[@"$userId"];
        NSParameterAssert(userId);
        if (userId) {
            _userId = [userId copy];
            [mutableRawObject removeObjectForKey:@"$userId"];
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

//- (NSString *)identifier {
//    if (_identifier == nil) {
//        NSString *identifierString = [self.scope stringByAppendingString:self.scopeId];
//        NSData *identifierStringData = [identifierString dataUsingEncoding:NSUTF8StringEncoding];
//        NSData *identifierHashData = uint256_data([identifierStringData SHA256_2]);
//        _identifier = [identifierHashData base58String];
//    }
//    return _identifier;
//}

//- (void)setAction:(DPDocumentAction)action error:(NSError *_Nullable __autoreleasing *)error {
//    if (action == DPDocumentAction_Delete && self.data.count != 0) {
//        if (error != NULL) {
//            *error = [NSError errorWithDomain:DPErrorDomain
//                                         code:DPErrorCode_DataIsNotAllowedWithActionDelete
//                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
//        }
//
//        return;
//    }
//
//    _action = action;
//    [self resetSerializedValues];
//}

- (void)setData:(DSStringValueDictionary *)data error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(data);

//    if (self.action == DPDocumentAction_Delete && data.count != 0) {
//        if (error != NULL) {
//            *error = [NSError errorWithDomain:DPErrorDomain
//                                         code:DPErrorCode_DataIsNotAllowedWithActionDelete
//                                     userInfo:@{NSDebugDescriptionErrorKey : self}];
//        }
//
//        return;
//    }

    _data = data;
    [self resetSerializedValues];
}

- (void)resetSerializedValues {
    [super resetSerializedValues];
    _keyValueDictionary = nil;
}

#pragma mark - DPPSerializableObject

@synthesize keyValueDictionary = _keyValueDictionary;

- (DSMutableStringValueDictionary *)keyValueDictionary {
    if (_keyValueDictionary == nil) {
        DSMutableStringValueDictionary *json = [[DSMutableStringValueDictionary alloc] init];
        json[@"$type"] = self.type;
        json[@"$contractId"] = self.contractId;
        json[@"$userId"] = self.userId;
        json[@"$entropy"] = self.entropy;
        json[@"$rev"] = self.revision;
        [json addEntriesFromDictionary:self.data];
        _keyValueDictionary = json;
    }
    return _keyValueDictionary;
}

@end

NS_ASSUME_NONNULL_END
