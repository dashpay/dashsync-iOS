//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSOperation (DSOperationKit)

- (void)ds_addCompletionBlockInMainQueue:(nullable void (^)(__kindof NSOperation *operation))block;
- (void)ds_addCompletionBlock:(nullable void (^)(__kindof NSOperation *operation))block;

- (void)ds_addCancelBlockInMainQueue:(nullable void (^)(__kindof NSOperation *operation))cancelBlock;
- (void)ds_addCancelBlock:(nullable void (^)(__kindof NSOperation *operation))cancelBlock;

- (void)ds_addDependencies:(NSArray<NSOperation *> *)dependencies;

@end

NS_ASSUME_NONNULL_END
