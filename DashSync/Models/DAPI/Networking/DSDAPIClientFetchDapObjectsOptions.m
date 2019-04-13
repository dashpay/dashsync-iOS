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

#import "DSDAPIClientFetchDapObjectsOptions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSDAPIClientFetchDapObjectsOptions

- (instancetype)initWithWhereQuery:(nullable NSDictionary *)where
                           orderBy:(nullable NSDictionary *)orderBy
                             limit:(nullable NSNumber *)limit
                           startAt:(nullable NSNumber *)startAt
                        startAfter:(nullable NSNumber *)startAfter {
    self = [super init];
    if (self) {
        _where = [where copy];
        _orderBy = [orderBy copy];
        _limit = limit;
        _startAt = startAt;
        _startAfter = startAfter;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
