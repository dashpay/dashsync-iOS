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

#import "NSData+DPSchemaUtils.h"

#import <CommonCrypto/CommonDigest.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSData (DSSchemaUtils)

- (NSData *)dp_SHA256Digest {
    unsigned char result[CC_SHA256_DIGEST_LENGTH];

    CC_SHA256(self.bytes, (CC_LONG)self.length, result);
    return [[NSData alloc] initWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
}

- (NSData *)dp_reverseData {
    NSMutableData *data = [[NSMutableData alloc] init];
    for (NSInteger i = self.length - 1; i >= 0; i--) {
        [data appendBytes:&self.bytes[i] length:1];
    }
    return [data copy];
}

@end

NS_ASSUME_NONNULL_END
