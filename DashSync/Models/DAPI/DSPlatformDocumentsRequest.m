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
#import "NSString+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import <DAPI-GRPC/Platform.pbrpc.h>
#import <DAPI-GRPC/Platform.pbobjc.h>
#import "DPContract.h"
#import "NSPredicate+CBORData.h"
#import "NSObject+DSCborEncoding.h"
#import "DPContract.h"

@implementation DSPlatformDocumentsRequest

-(instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

+(instancetype)dpnsRequestForUsername:(NSString*)username inDomain:(NSString*)domain {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel == %@ && normalizedParentDomainName == %@",[username lowercaseString],[domain lowercaseString]];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForUserId:(NSData*)userId {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"records.dashUniqueIdentityId == %@",userId];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForUsernames:(NSArray*)usernames inDomain:(NSString*)domain {
    NSMutableArray * lowercaseUsernames = [NSMutableArray array];
    for (NSString * username in usernames) {
        [lowercaseUsernames addObject:[username lowercaseString]];
    }
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    //UInt256 hashOfName = [[name dataUsingEncoding:NSUTF8StringEncoding] SHA256_2];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel IN %@ && normalizedParentDomainName == %@",lowercaseUsernames,[domain lowercaseString]];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = (uint32_t)usernames.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForUsernameStartsWithSearch:(NSString*)usernamePrefix inDomain:(NSString*)domain {
    return [self dpnsRequestForUsernameStartsWithSearch:usernamePrefix inDomain:domain offset:0 limit:100];
}

+(instancetype)dpnsRequestForUsernameStartsWithSearch:(NSString*)usernamePrefix inDomain:(NSString*)domain offset:(uint32_t)offset limit:(uint32_t)limit {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel BEGINSWITH %@ && normalizedParentDomainName == %@",usernamePrefix,[domain lowercaseString]];
    platformDocumentsRequest.startAt = offset;
    platformDocumentsRequest.limit = limit;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"domain";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForContactRequestsForSendingUserId:(NSData*)userId since:(NSTimeInterval)timestamp {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    uint64_t millisecondTimestamp = timestamp * 1000;
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@ && %K >= %@",@"$ownerId",userId,@"$createdAt",@(millisecondTimestamp)];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"$ownerId" ascending:YES],[NSSortDescriptor sortDescriptorWithKey:@"$createdAt" ascending:YES]];
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForContactRequestsForRecipientUserId:(NSData*)userId since:(NSTimeInterval)timestamp {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    uint64_t millisecondTimestamp = timestamp * 1000;
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"toUserId == %@ && %K >= %@",userId,@"$createdAt",@(millisecondTimestamp)];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"toUserId" ascending:YES],[NSSortDescriptor sortDescriptorWithKey:@"$createdAt" ascending:YES]];
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForContactRequestForSendingUserId:(NSData*)userId toRecipientUserId:(NSData*)toUserId {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@ && toUserId == %@",@"$ownerId",userId,toUserId];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForProfileWithUserId:(NSData*)userId {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@",@"$ownerId",userId];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"profile";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForProfilesWithUserIds:(NSArray<NSData*>*)userIds {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K IN %@",@"$ownerId",userIds];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = (uint32_t)userIds.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"profile";
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForPreorderSaltedHashes:(NSArray*)preorderSaltedHashes {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    if (preorderSaltedHashes.count == 1) {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"saltedDomainHash == %@",[preorderSaltedHashes firstObject]];
    } else {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"saltedDomainHash IN %@",preorderSaltedHashes];
    }
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = (uint32_t)preorderSaltedHashes.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"preorder";
    return platformDocumentsRequest;
}

-(NSData*)whereData {
    return [self.predicate dashPlatormWhereData];
}
-(NSData*)orderByData {
    NSMutableArray * sortDescriptorsArray = [NSMutableArray array];
    for (NSSortDescriptor * sortDescriptor in self.sortDescriptors) {
       [sortDescriptorsArray addObject:@[sortDescriptor.key,sortDescriptor.ascending?@"asc":@"desc"]];
    }
    return [sortDescriptorsArray ds_cborEncodedObject];
}

-(GetDocumentsRequest*)getDocumentsRequest {
    NSAssert(self.tableName, @"Table name must be set");
    GetDocumentsRequest * getDocumentsRequest = [[GetDocumentsRequest alloc] init];
    getDocumentsRequest.documentType = self.tableName;
    getDocumentsRequest.dataContractId = uint256_data(self.contract.contractId);
    getDocumentsRequest.where = [self whereData];
    if ([self.sortDescriptors count]) {
        getDocumentsRequest.orderBy = [self orderByData];
    }
    getDocumentsRequest.startAt = self.startAt;
    getDocumentsRequest.limit = self.limit;
    DSLog(@"Sending request to Contract %@",getDocumentsRequest.dataContractId.base58String);
    return getDocumentsRequest;
}

@end
