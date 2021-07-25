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

#import "NSData+DSMerkAVLTree.h"
#import "merk.h"

@implementation NSData (DSMerkAVLTree)

- (NSData *)executeProofReturnElementDictionary:(NSDictionary **)rElementDictionary {
    const ExecuteProofResult *result = execute_proof_c(self.bytes, self.length);
    if (result == nil) {
        return nil;
    }
    NSMutableDictionary *mElementDictionary = [[NSMutableDictionary alloc] initWithCapacity:result->element_count];
    NSData *rootHash = [NSData dataWithBytes:result->hash length:32];
    for (uint8_t i = 0; i < result->element_count; i++) {
        Element *element = result->elements[i];
        [mElementDictionary setObject:[NSData dataWithBytes:element->value length:element->value_length] forKey:[NSData dataWithBytes:element->key length:element->key_length]];
    }
    *rElementDictionary = [mElementDictionary copy];
    return rootHash;
}

@end
