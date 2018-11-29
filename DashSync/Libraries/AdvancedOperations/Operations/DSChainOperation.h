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

#import "DSChainableOperationProtocol.h"
#import "DSOperation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 A subclass of `DSOperation` that executes zero or more operations as part of its
 own execution in serial queue, each opearation is passing data to next one. 
 This class of operation is very useful for abstracting several
 smaller operations into a larger operation.
 
 DSChainOperation is simmilar to DSGroupOpeartion but you don't need to establish
 dependencies between opearions and you are not responsible to pass data between them.
 */
@interface DSChainOperation : DSOperation

@property (nonatomic, assign) BOOL finishIfProducedAnyError;

+ (instancetype)operationWithOperations:(nullable NSArray<NSOperation<DSChainableOperationProtocol> *> *)operations;
- (instancetype)initWithOperations:(nullable NSArray<NSOperation<DSChainableOperationProtocol> *> *)operations;
- (void)addOperation:(NSOperation *)operation;
- (void)operationDidFinish:(NSOperation *)operation withErrors:(NSArray *)errors;
- (void)aggregateError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
