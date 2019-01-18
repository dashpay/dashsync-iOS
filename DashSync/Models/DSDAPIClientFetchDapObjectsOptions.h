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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSDAPIClientFetchDapObjectsOptions : NSObject

@property (readonly, nullable, copy, nonatomic) NSDictionary *where;
@property (readonly, nullable, copy, nonatomic) NSDictionary *orderBy;
@property (readonly, nullable, strong, nonatomic) NSNumber *limit;
@property (readonly, nullable, strong, nonatomic) NSNumber *startAt;
@property (readonly, nullable, strong, nonatomic) NSNumber *startAfter;

/**
 DSDAPIClientFetchDapObjectsOptions represents Fetch DAP Objects options
 
 @param where Mongo-like query  https://docs.mongodb.com/manual/reference/operator/query/
 @param orderBy Mongo-like sort field  https://docs.mongodb.com/manual/reference/method/cursor.sort/
 @param limit How many objects to fetch  https://docs.mongodb.com/manual/reference/method/cursor.limit/
 @param startAt Number of objects to skip  https://docs.mongodb.com/manual/reference/method/cursor.skip/
 @param startAfter Exclusive skip  https://docs.mongodb.com/manual/reference/method/cursor.skip/
 @return An initialized options object
 */
- (instancetype)initWithWhereQuery:(nullable NSDictionary *)where
                           orderBy:(nullable NSDictionary *)orderBy
                             limit:(nullable NSNumber *)limit
                           startAt:(nullable NSNumber *)startAt
                        startAfter:(nullable NSNumber *)startAfter;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
