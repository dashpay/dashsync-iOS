//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//  Copyright © 2015 Michal Zaborowski. All rights reserved.
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

#import "DSChainableCondition.h"
#import "DSOperationConditionResult.h"

@interface DSChainableCondition ()

@property (nonatomic, strong) NSOperation<DSChainableOperationProtocol> *chainOperation;

@end

@implementation DSChainableCondition

- (instancetype)initWithOperation:(NSOperation<DSChainableOperationProtocol> *)operation {
    self = [super init];
    if (self) {
        self.chainOperation = operation;
    }
    return self;
}

+ (instancetype)chainConditionForOperation:(NSOperation<DSChainableOperationProtocol> *)operation {
    return [[[self class] alloc] initWithOperation:operation];
}

#pragma mark - Subclass

- (NSOperation *)dependencyForOperation:(DSOperation *)operation {
    return self.chainOperation;
}

- (void)evaluateForOperation:(DSOperation *)operation completion:(void (^)(DSOperationConditionResult *))completion {
    completion([DSOperationConditionResult satisfiedResult]);
}

@end
