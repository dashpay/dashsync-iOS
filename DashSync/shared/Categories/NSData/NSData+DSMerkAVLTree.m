//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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

#import "DSPlatformTreeQuery.h"
#import "NSData+DSCborDecoding.h"
#import "NSData+DSMerkAVLTree.h"
#import "NSData+Dash.h"
#import "merk.h"

@implementation NSData (DSMerkAVLTree)

- (NSData *)executeProofReturnElementDictionary:(NSDictionary **)rElementDictionary query:(DSPlatformTreeQuery *)query decode:(BOOL)decode usesVersion:(BOOL)usesVersion error:(NSError **)error {
    ExecuteProofResult *result;
    if (query) {
        result = execute_proof_query_keys_c(self.bytes, self.length, query.keys);
    } else {
        result = execute_proof_c(self.bytes, self.length);
    }
    if (result == nil) {
        return nil;
    }
    NSMutableDictionary *mElementDictionary = [[NSMutableDictionary alloc] initWithCapacity:result->element_count];
    NSData *rootHash = [NSData dataWithBytes:result->hash length:32];
    for (uint8_t i = 0; i < result->element_count; i++) {
        Element *element = result->elements[i];
        //        if (element->bool_) {
        NSData *value = [NSData dataWithBytes:element->value length:element->value_length];
        NSMutableDictionary *storedItemDictionary = [NSMutableDictionary dictionary];
        if (usesVersion) {
            uint32_t version = [value UInt32AtOffset:0];
            value = [value subdataWithRange:NSMakeRange(4, value.length - 4)];
            [storedItemDictionary setObject:@(version) forKey:@(DSPlatformStoredMessage_Version)];
        }
        if (decode) {
            id documentValue = [value ds_decodeCborError:error];
            if (*error) {
                return nil;
            }
            [storedItemDictionary setObject:documentValue forKey:@(DSPlatformStoredMessage_Item)];
            [mElementDictionary setObject:[storedItemDictionary copy] forKey:[NSData dataWithBytes:element->key length:element->key_length]];
        } else {
            [storedItemDictionary setObject:value forKey:@(DSPlatformStoredMessage_Item)];
            [mElementDictionary setObject:[storedItemDictionary copy] forKey:[NSData dataWithBytes:element->key length:element->key_length]];
        }
        //        } else {
        //            [mElementDictionary setObject:[NSNull null] forKey:[NSData dataWithBytes:element->key length:element->key_length]];
        //        }
    }
    *rElementDictionary = [mElementDictionary copy];
    destroy_proof_c(result);
    return rootHash;
}

@end
