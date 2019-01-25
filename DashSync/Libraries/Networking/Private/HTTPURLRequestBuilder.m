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

#import "HTTPURLRequestBuilder.h"

// Based on AFNetworking
// https://github.com/AFNetworking/AFNetworking/blob/master/AFNetworking/AFURLRequestSerialization.m

extern NSString *PercentEscapedStringFromString(NSString *string);
extern NSArray *QueryStringPairsFromKeyAndValue(NSString *key, id value);
extern NSArray *QueryStringPairsFromDictionary(NSDictionary *dictionary);

#pragma mark - Pair

@interface MLWQueryStringPair : NSObject

@property (strong, nonatomic) id field;
@property (strong, nonatomic) id value;

- (instancetype)initWithField:(id)field value:(id)value;
- (NSString *)URLEncodedStringValue;

@end

@implementation MLWQueryStringPair

- (instancetype)initWithField:(id)field value:(id)value {
    self = [super init];
    if (self) {
        self.field = field;
        self.value = value;
    }

    return self;
}

- (NSString *)URLEncodedStringValue {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return PercentEscapedStringFromString([self.field description]);
    }
    else {
        return [NSString stringWithFormat:@"%@=%@", PercentEscapedStringFromString([self.field description]), PercentEscapedStringFromString([self.value description])];
    }
}

@end

#pragma mark - Builder

@implementation HTTPURLRequestBuilder

+ (nullable NSData *)jsonDataFromParameters:(nullable NSDictionary *)parameters {
    if (!parameters) {
        return nil;
    }

    NSDictionary *_parameters = parameters;

    NSError *serializeError = nil;
    NSData *result = [NSJSONSerialization dataWithJSONObject:_parameters
                                                     options:kNilOptions
                                                       error:&serializeError];
    NSAssert(result, serializeError.localizedDescription);
    return result;
}

+ (NSString *)queryStringFromParameters:(nullable NSDictionary *)parameters {
    if (!parameters) {
        return @"";
    }

    NSDictionary *_parameters = parameters;

    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (MLWQueryStringPair *pair in QueryStringPairsFromDictionary(_parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValue]];
    }

    return [mutablePairs componentsJoinedByString:@"&"];
}

+ (NSString *)percentEscapedStringFromString:(NSString *)string {
    return PercentEscapedStringFromString(string);
}

@end

#pragma mark - Helpers

NSArray *QueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return QueryStringPairsFromKeyAndValue(nil, dictionary);
}

NSArray *QueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];

    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description"
                                                                     ascending:YES
                                                                      selector:@selector(compare:)];

    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which
        // is important when deserializing potentially ambiguous sequences, such as
        // an array of dictionaries
        for (id nestedKey in
             [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                NSCAssert(nestedValue != value, @"Infinite recursion");
                [mutableQueryStringComponents addObjectsFromArray:
                                                  QueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    }
    else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            NSCAssert(nestedValue != value, @"Infinite recursion");
            [mutableQueryStringComponents addObjectsFromArray:QueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    }
    else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            NSCAssert(obj != value, @"Infinite recursion");
            [mutableQueryStringComponents addObjectsFromArray:QueryStringPairsFromKeyAndValue(key, obj)];
        }
    }
    else {
        [mutableQueryStringComponents addObject:[[MLWQueryStringPair alloc] initWithField:key value:value]];
    }

    return mutableQueryStringComponents;
}

/**
 Returns a percent-escaped string following RFC 3986 for a query string key or
 value.
 RFC 3986 states that the following characters are "reserved" characters.
 - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
 - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
 In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not
 be escaped to allow
 query strings to include a URL. Therefore, all "reserved" characters with the
 exception of "?" and "/"
 should be percent-escaped in the query string.
 - parameter string: The string to be percent-escaped.
 - returns: The percent-escaped string.
 */
NSString *PercentEscapedStringFromString(NSString *string) {
    static NSString *const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString *const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";

    NSMutableCharacterSet *allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];

    // see https://github.com/AFNetworking/AFNetworking/pull/3028
    // return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];

    static NSUInteger const batchSize = 50;

    NSUInteger index = 0;
    NSMutableString *escaped = @"".mutableCopy;

    while (index < string.length) {
        NSUInteger length = MIN(string.length - index, batchSize);
        NSRange range = NSMakeRange(index, length);

        // To avoid breaking up character sequences such as 👴🏻👮🏽
        range = [string rangeOfComposedCharacterSequencesForRange:range];

        NSString *substring = [string substringWithRange:range];
        NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [escaped appendString:encoded];

        index += range.length;
    }

    return escaped;
}
