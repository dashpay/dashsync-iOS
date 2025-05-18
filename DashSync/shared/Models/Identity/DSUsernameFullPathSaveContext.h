//  
//  Created by Vladimir Pirogov
//  Copyright © 2025 Dash Core Group. All rights reserved.
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

@interface DSUsernameFullPathSaveContext : NSObject
@property (nonatomic, assign) NSArray<NSString *> *usernames;
@property (nonatomic, assign) DSIdentity *identity;
@property (nonatomic, assign) NSManagedObjectContext *context;
+ (instancetype)contextWithUsernames:(NSArray<NSString *> *)usernames forIdentity:(DSIdentity *)identity inContext:(NSManagedObjectContext *)context;
//- (void)setAndSaveUsernameFullPaths:(DUsernameStatus *)status;

@end

NS_ASSUME_NONNULL_END
