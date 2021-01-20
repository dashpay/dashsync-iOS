//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSPlatformDocumentType)
{
    DSPlatformDocumentType_Contract = 1,
    DSPlatformDocumentType_Document = 2,
};

@class GetDocumentsRequest, DPContract;

@interface DSPlatformDocumentsRequest : NSObject

@property (nonatomic, strong) NSPredicate *predicate;
@property (nonatomic, strong) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (nonatomic, assign) uint32_t startAt;
@property (nonatomic, assign) uint32_t limit;
@property (nonatomic, strong) NSString *tableName;
@property (nonatomic, strong) DPContract *contract;
@property (nonatomic, assign) DSPlatformDocumentType type;

+ (instancetype)dpnsRequestForUserId:(NSData *)userId;

+ (instancetype)dpnsRequestForUsername:(NSString *)username inDomain:(NSString *)domain;

+ (instancetype)dpnsRequestForUsernames:(NSArray *)usernames inDomain:(NSString *)domain;

+ (instancetype)dpnsRequestForUsernameStartsWithSearch:(NSString *)usernamePrefix inDomain:(NSString *)domain;

+ (instancetype)dpnsRequestForUsernameStartsWithSearch:(NSString *)usernamePrefix inDomain:(NSString *)domain offset:(uint32_t)offset limit:(uint32_t)limit;

+ (instancetype)dpnsRequestForPreorderSaltedHashes:(NSArray *)preorderSaltedHashes;

+ (instancetype)dashpayRequestForContactRequestForSendingUserId:(NSData *)userId toRecipientUserId:(NSData *)toUserId;

+ (instancetype)dashpayRequestForContactRequestsForSendingUserId:(NSData *)userId since:(NSTimeInterval)timestamp;

+ (instancetype)dashpayRequestForContactRequestsForRecipientUserId:(NSData *)userId since:(NSTimeInterval)timestamp;

+ (instancetype)dashpayRequestForProfileWithUserId:(NSData *)userId;

+ (instancetype)dashpayRequestForProfilesWithUserIds:(NSArray<NSData *> *)userIds;

- (GetDocumentsRequest *)getDocumentsRequest;

@end

NS_ASSUME_NONNULL_END
