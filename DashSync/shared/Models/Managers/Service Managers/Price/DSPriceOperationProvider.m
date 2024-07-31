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

#import "DSPriceOperationProvider.h"

#import "DSFetchDashRetailPricesOperation.h"
#import "DSFetchFirstFallbackPricesOperation.h"
#import "DSFetchSecondFallbackPricesOperation.h"
#import "DSNoSucceededDependenciesCondition.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSPriceOperationProvider

+ (DSOperation *)fetchPrices:(void (^)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *_Nullable priceSource, NSError *_Nullable error))completion {
    void (^mainThreadCompletion)(NSArray<DSCurrencyPriceObject *> *_Nullable, NSString *_Nullable priceSource, NSError *_Nullable error) = ^(NSArray<DSCurrencyPriceObject *> *_Nullable prices, NSString *_Nullable priceSource, NSError *_Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(prices, priceSource, error);
        });
    };

    DSNoSucceededDependenciesCondition *condition = [DSNoSucceededDependenciesCondition new];

    DSOperation *operation1 = [[DSFetchDashRetailPricesOperation alloc] initOperationWithCompletion:mainThreadCompletion];

    DSOperation *operation2 = [[DSFetchFirstFallbackPricesOperation alloc] initOperationWithCompletion:mainThreadCompletion];
    [operation2 addCondition:condition];
    [operation2 addDependency:operation1];

    DSOperation *operation3 = [[DSFetchSecondFallbackPricesOperation alloc] initOperationWithCompletion:mainThreadCompletion];
    [operation3 addCondition:condition];
    [operation3 addDependency:operation1];
    [operation3 addDependency:operation2];

    DSGroupOperation *aggregateOperation = [DSGroupOperation operationWithOperations:@[operation1, operation2, operation3]];

    return aggregateOperation;
}

@end

NS_ASSUME_NONNULL_END
