//
//  Created by Andrew Podkovyrin
//  Copyright © 2019-2019 Dash Core Group. All rights reserved.
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

#import "NSURLRequest+DCcURL.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSURLRequest (DCcURL)

- (NSString *)escapeQuotesInString:(NSString *)string {
    NSParameterAssert(string.length);

    return [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

- (NSString *)dc_cURL {
    // `-k` allows insecure connections
    NSMutableString *cURLString = [NSMutableString stringWithFormat:@"curl -k -X %@ --dump-header -", self.HTTPMethod];

    for (NSString *key in self.allHTTPHeaderFields) {
        NSString *headerKey = [self escapeQuotesInString:key];
        NSString *headerValue = [self escapeQuotesInString:self.allHTTPHeaderFields[key]];

        [cURLString appendFormat:@" -H \"%@: %@\"", headerKey, headerValue];
    }

    NSString *bodyString = [[NSString alloc] initWithData:self.HTTPBody encoding:NSUTF8StringEncoding];
    if (bodyString.length) {
        bodyString = [self escapeQuotesInString:bodyString];
        [cURLString appendFormat:@" -d \"%@\"", bodyString];
    }

    [cURLString appendFormat:@" \"%@\"", self.URL.absoluteString];

    return cURLString;
}

@end

NS_ASSUME_NONNULL_END
