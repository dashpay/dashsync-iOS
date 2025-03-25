//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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
#import "DSIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSIdentity (ContactRequest)

- (void)fetchContactRequests:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion;
- (void)fetchOutgoingContactRequests:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion;
- (void)fetchOutgoingContactRequestsInContext:(NSManagedObjectContext *)context
                                   startAfter:(NSData*_Nullable)startAfter
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue;
- (void)fetchIncomingContactRequests:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion;
- (void)fetchIncomingContactRequestsInContext:(NSManagedObjectContext *)context
                                   startAfter:(NSData*_Nullable)startAfter
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue;

@end

NS_ASSUME_NONNULL_END
