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

#import "NSOperation+DSOperationKit.h"

@implementation NSOperation (DSOperationKit)

- (void)ds_addCompletionBlockInMainQueue:(void (^)(__kindof NSOperation *operation))block {
    if (!block) {
        return;
    }
    void (^existing)(void) = self.completionBlock;
    __weak typeof(self) weakSelf = self;
    if (existing) {
        /*
         If we already have a completion block, we construct a new one by
         chaining them together.
         */
        self.completionBlock = ^{
            existing();
            __strong typeof(weakSelf) strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                block(strongSelf);
            });
        };
    } else {
        self.completionBlock = ^() {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                block(strongSelf);
            });
        };
    }
}

/**
 Add a completion block to be executed after the `NSOperation` enters the
 "finished" state.
 */
- (void)ds_addCompletionBlock:(void (^)(__kindof NSOperation *operation))block {
    if (!block) {
        return;
    }
    void (^existing)(void) = self.completionBlock;
    __weak typeof(self) weakSelf = self;
    if (existing) {
        /*
         If we already have a completion block, we construct a new one by
         chaining them together.
         */
        self.completionBlock = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            existing();
            block(strongSelf);
        };
    } else {
        self.completionBlock = ^() {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            block(strongSelf);
        };
    }
}

- (void)ds_addCancelBlockInMainQueue:(nullable void (^)(__kindof NSOperation *_Nonnull operation))cancelBlock {
    if (!cancelBlock) {
        return;
    }
    [self ds_addCompletionBlockInMainQueue:^(__kindof NSOperation *_Nonnull operation) {
        if (cancelBlock && operation.isCancelled) {
            cancelBlock(operation);
        }
    }];
}

- (void)ds_addCancelBlock:(nullable void (^)(__kindof NSOperation *_Nonnull operation))cancelBlock {
    if (!cancelBlock) {
        return;
    }
    [self ds_addCompletionBlock:^(__kindof NSOperation *_Nonnull operation) {
        if (cancelBlock && operation.isCancelled) {
            cancelBlock(operation);
        }
    }];
}

/// Add multiple depdendencies to the operation.
- (void)ds_addDependencies:(NSArray<NSOperation *> *)dependencies {
    for (NSOperation *dependency in dependencies) {
        [self addDependency:dependency];
    }
}

@end
