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

#import "DSPlatformDocumentsRequest.h"
#import "DPContract.h"
#import "DSDirectionalKey.h"
#import "DSDirectionalRange.h"
#import "DSPlatformQuery.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSObject+DSCborEncoding.h"
#import "NSPredicate+CBORData.h"
#import "NSString+Bitcoin.h"
#import <DAPI-GRPC/Platform.pbobjc.h>
#import <DAPI-GRPC/Platform.pbrpc.h>

@interface DSPlatformDocumentsRequest ()

@property (nonatomic, readonly) NSData *secondaryIndexPathData;
@property (nonatomic, assign) DSPlatformQueryType queryType;

@end

@implementation DSPlatformDocumentsRequest

- (instancetype)init {
    self = [super init];
    return self;
}

+ (instancetype)dpnsRequestForUsername:(NSString *)username inDomain:(NSString *)domain {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"normalizedParentDomainName == %@", [domain lowercaseString]];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel == %@", [username lowercaseString]];
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.queryType = DSPlatformQueryType_OneElement;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dpnsRequestForUserId:(NSData *)userId {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"records.dashUniqueIdentityId == %@", userId];
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.queryType = DSPlatformQueryType_RangeOverIndex;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dpnsRequestForUsernames:(NSArray *)usernames inDomain:(NSString *)domain {
    NSMutableArray *lowercaseUsernames = [NSMutableArray array];
    for (NSString *username in usernames) {
        [lowercaseUsernames addObject:[username lowercaseString]];
    }
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"normalizedParentDomainName == %@", [domain lowercaseString]];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel IN %@", lowercaseUsernames];
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = (uint32_t)usernames.count;
    platformDocumentsRequest.queryType = DSPlatformQueryType_IndividualElements; // Many non consecutive elements in the tree
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dpnsRequestForUsernameStartsWithSearch:(NSString *)usernamePrefix inDomain:(NSString *)domain {
    return [self dpnsRequestForUsernameStartsWithSearch:usernamePrefix inDomain:domain startAfter:nil limit:100];
}

+ (instancetype)dpnsRequestForUsernameStartsWithSearch:(NSString *)usernamePrefix inDomain:(NSString *)domain startAfter:(NSData* _Nullable)startAfter limit:(uint32_t)limit {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"normalizedParentDomainName == %@", [domain lowercaseString]];
    if (usernamePrefix.length) {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel BEGINSWITH %@", usernamePrefix];
        platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"normalizedLabel" ascending:YES]];
    }
    platformDocumentsRequest.startAt = startAfter;
    platformDocumentsRequest.startAtIncluded = false;
    platformDocumentsRequest.limit = limit;
    platformDocumentsRequest.queryType = DSPlatformQueryType_RangeOverValue;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dashpayRequestForContactRequestsForSendingUserId:(NSData *)userId since:(NSTimeInterval)timestamp startAfter:(NSData* _Nullable)startAfter {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    uint64_t millisecondTimestamp = timestamp * 1000;
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"%K == %@", @"$ownerId", userId];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K >= %@", @"$createdAt", @(millisecondTimestamp)];
    platformDocumentsRequest.startAt = startAfter;
    platformDocumentsRequest.startAtIncluded = false;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"$createdAt" ascending:YES]];
    platformDocumentsRequest.queryType = DSPlatformQueryType_RangeOverValue;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dashpayRequestForContactRequestsForRecipientUserId:(NSData *)userId since:(NSTimeInterval)timestamp startAfter:(NSData* _Nullable)startAfter {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    uint64_t millisecondTimestamp = timestamp * 1000;
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"toUserId == %@", userId];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K >= %@", @"$createdAt", @(millisecondTimestamp)];
    platformDocumentsRequest.startAt = startAfter;
    platformDocumentsRequest.startAtIncluded = false;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"$createdAt" ascending:YES]];
    platformDocumentsRequest.queryType = DSPlatformQueryType_RangeOverValue;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dashpayRequestForContactRequestForSendingUserId:(NSData *)userId toRecipientUserId:(NSData *)toUserId {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.pathPredicate = [NSPredicate predicateWithFormat:@"%K == %@ && toUserId == %@", @"$ownerId", userId, toUserId];
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.queryType = DSPlatformQueryType_RangeOverIndex;
    platformDocumentsRequest.tableName = @"contactRequest";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dashpayRequestForProfileWithUserId:(NSData *)userId {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@", @"$ownerId", userId];
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.queryType = DSPlatformQueryType_OneElement;
    platformDocumentsRequest.tableName = @"profile";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dashpayRequestForProfilesWithUserIds:(NSArray<NSData *> *)userIds {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K IN %@", @"$ownerId", userIds];
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = (uint32_t)userIds.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.queryType = DSPlatformQueryType_IndividualElements;
    platformDocumentsRequest.tableName = @"profile";
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"$ownerId" ascending:YES]];
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

+ (instancetype)dpnsRequestForPreorderSaltedHashes:(NSArray *)preorderSaltedHashes {
    DSPlatformDocumentsRequest *platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    if (preorderSaltedHashes.count == 1) {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"saltedDomainHash == %@", [preorderSaltedHashes firstObject]];
        platformDocumentsRequest.queryType = DSPlatformQueryType_OneElement;
    } else {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"saltedDomainHash IN %@", preorderSaltedHashes];
        platformDocumentsRequest.queryType = DSPlatformQueryType_IndividualElements;
        platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"saltedDomainHash" ascending:YES]];
    }
    platformDocumentsRequest.startAt = nil;
    platformDocumentsRequest.limit = (uint32_t)preorderSaltedHashes.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"preorder";
    platformDocumentsRequest.prove = DSPROVE_PLATFORM_SINDEXES;
    return platformDocumentsRequest;
}

- (NSData *)whereData {
    NSPredicate *predicate = nil;
    if (self.pathPredicate && self.predicate) {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[self.pathPredicate, self.predicate]];
    } else if (self.pathPredicate) {
        predicate = self.pathPredicate;
    } else if (self.predicate) {
        predicate = self.predicate;
    } else {
        NSAssert(NO, @"We should always have a predicate or a path predicate");
        return nil;
    }
    return [predicate dashPlatormWhereData];
}

- (NSData *)orderByData {
    return [[self orderByRanges] ds_cborEncodedObject];
}

- (GetDocumentsRequest *)getDocumentsRequest {
    NSAssert(self.tableName, @"Table name must be set");
    GetDocumentsRequest *getDocumentsRequest = [[GetDocumentsRequest alloc] init];
    getDocumentsRequest.documentType = self.tableName;
    getDocumentsRequest.dataContractId = uint256_data(self.contract.contractId);
    getDocumentsRequest.where = [self whereData];
    if ([self.sortDescriptors count]) {
        getDocumentsRequest.orderBy = [self orderByData];
    }
    if (self.startAt) {
        if (self.startAtIncluded) {
            getDocumentsRequest.startAt = self.startAt;
        } else {
            getDocumentsRequest.startAfter = self.startAt;
        }
    }
    getDocumentsRequest.limit = self.limit;
    getDocumentsRequest.prove = self.prove;
    DSLog(@"Sending request to Contract %@", getDocumentsRequest.dataContractId.base58String);
    return getDocumentsRequest;
}

- (NSArray<DSDirectionalKey *> *)orderByRanges {
    NSMutableArray *sortDescriptorsArray = [NSMutableArray array];
    for (NSSortDescriptor *sortDescriptor in self.sortDescriptors) {
        [sortDescriptorsArray addObject:@[sortDescriptor.key, sortDescriptor.ascending?@"asc":@"desc"]];
    }
    return [sortDescriptorsArray copy];
}

- (NSData *)secondaryIndexPathData {
    return [self.predicate secondaryIndexPathForQueryType:self.queryType];
}

- (NSArray<NSData *> *)path {
    NSMutableArray *paths = [NSMutableArray array];
    // First we need to add the documents tree
    [paths addObject:[NSData dataWithUInt8:DSPlatformDictionary_Documents]];
    // Then we need to add the contract id
    [paths addObject:uint256_data(self.contract.contractId)];
    // Then we need to add the secondary index
    [paths addObject:self.secondaryIndexPathData];

    return [paths copy];
}

- (DSPlatformQuery *)expectedResponseQuery {
    return nil;
    //    switch (self.queryType) {
    //        case DSPlatformQueryType_OneElement:
    //            return [DSPlatformQuery platformQueryForKeys:@[[self.predicate singleElementQueryKey]] inPath:self.path];
    //        case DSPlatformQueryType_IndividualElements:
    //            return [DSPlatformQuery platformQueryForKeys:[self.predicate multipleElementQueryKey] inPath:self.path];
    //        case DSPlatformQueryType_RangeOverValue:
    //            return [DSPlatformQuery platformQueryDocumentTreeQuery:self.predicate.platformTreeQuery];
    //        case DSPlatformQueryType_RangeOverIndex:
    //        {
    //            //Todo, this might be wrong, need to think about it more
    //            //DSDirectionalRange * indexRange = [[DSDirectionalRange alloc] initForKey:nil withLowerBounds:[NSData dataWithUInt32:self.startAt] ascending:YES includeLowerBounds:YES];
    //            //return [DSPlatformQuery platformQueryForRanges:@[indexRange] inPath:self.pathPredicate];
    //            return nil;
    //        }
    //    }
}

@end
