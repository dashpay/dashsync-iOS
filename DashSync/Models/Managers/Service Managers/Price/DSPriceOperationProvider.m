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

#import "DSPriceOperationProvider.h"

#import "DSFetchSparkPricesOperation.h"
#import "DSFetchSecondFallbackPricesOperation.h"
#import "DSFetchFirstFallbackPricesOperation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSPriceOperationProvider

+ (DSOperation *)fetchPrices:(void(^)(NSArray<DSCurrencyPriceObject *> * _Nullable prices))completion {
    return [self firstFallbackOperationWithCompletion:completion];
}

+ (DSOperation *)sparkOperationWithCompletion:(void(^)(NSArray<DSCurrencyPriceObject *> * _Nullable prices))completion {
    DSOperation *fetchSparkOperation = [[DSFetchSparkPricesOperation alloc] initOperationWithCompletion:^(NSArray<DSCurrencyPriceObject *> * _Nullable prices) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(prices);
        });
    }];
    return fetchSparkOperation;
}

+ (DSOperation *)firstFallbackOperationWithCompletion:(void(^)(NSArray<DSCurrencyPriceObject *> * _Nullable prices))completion {
    DSOperation *fetchSparkOperation = [[DSFetchFirstFallbackPricesOperation alloc] initOperationWithCompletion:^(NSArray<DSCurrencyPriceObject *> * _Nullable prices) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(prices);
        });
    }];
    return fetchSparkOperation;
}

+ (DSOperation *)secondFallbackOperationWithCompletion:(void(^)(NSArray<DSCurrencyPriceObject *> * _Nullable prices))completion {
    DSOperation *fetchSparkOperation = [[DSFetchSecondFallbackPricesOperation alloc] initOperationWithCompletion:^(NSArray<DSCurrencyPriceObject *> * _Nullable prices) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(prices);
        });
    }];
    return fetchSparkOperation;
}

@end

NS_ASSUME_NONNULL_END
