//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "DPSerializeUtils.h"

#import <TinyCborObjc/NSData+DSCborDecoding.h>
#import <TinyCborObjc/NSObject+DSCborEncoding.h>

#import "NSData+DPSchemaUtils.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DPSerializeUtils

+ (nullable NSData *)serializeObject:(NSObject *)object {
    return [object ds_cborEncodedObject];
}

+ (nullable NSData *)hashDataOfData:(NSData *)data {
    NSData *sha256Twice = [[data dp_SHA256Digest] dp_SHA256Digest];

    return sha256Twice;
}

+ (nullable NSString *)hashStringOfData:(NSData *)data {
    NSData *dataHash = [self hashDataOfData:data];
    if (!dataHash) {
        return nil;
    }

    NSString *hashString = [dataHash ds_hexStringFromData];

    return hashString;
}

+ (nullable NSData *)serializeAndHashObjectToData:(NSObject *)object {
    NSData *data = [self serializeObject:object];
    if (!data) {
        return nil;
    }

    return [self hashDataOfData:data];
}

+ (nullable NSString *)serializeAndHashObjectToString:(NSObject *)object {
    NSData *hash = [self serializeAndHashObjectToData:object];
    if (!hash) {
        return nil;
    }

    NSString *sha256String = [hash ds_hexStringFromData];

    return sha256String;
}

+ (nullable id)decodeSerializedObject:(NSData *)data error:(NSError *_Nullable __autoreleasing *)error {
    return [data ds_decodeCborError:error];
}

@end

NS_ASSUME_NONNULL_END
