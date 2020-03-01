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

+(instancetype)dpnsRequestForUserId:(NSString*)userId {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"records.dashIdentity == %@",userId];
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

+(instancetype)dashpayRequestForContactRequestsForSendingUserId:(NSString*)userId since:(NSTimeInterval)timestamp {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@ && timestamp >= %@",@"$userId",userId,@(timestamp)];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"$userId" ascending:YES],[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForContactRequestsForRecipientUserId:(NSString*)userId since:(NSTimeInterval)timestamp {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"toUserId == %@ && timestamp >= %@",userId,@(timestamp)];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 100;
    platformDocumentsRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"toUserId" ascending:YES],[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForContactRequestForSendingUserId:(NSString*)userId toRecipientUserId:(NSString*)toUserId {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@ && toUserId == %@",@"$userId",userId,toUserId];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"contactRequest";
    return platformDocumentsRequest;
}

+(instancetype)dashpayRequestForProfileWithUserId:(NSString*)userId {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@",@"$userId",userId];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    platformDocumentsRequest.tableName = @"profile";
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForPreorderSaltedHashes:(NSArray*)preorderSaltedHashes {
    NSMutableArray * preorderSaltedHashesAsHex = [NSMutableArray array];
    for (NSData* data in preorderSaltedHashes) {
        [preorderSaltedHashesAsHex addObject:data.hexString];
    }
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    if (preorderSaltedHashesAsHex.count == 1) {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"saltedDomainHash == %@",[preorderSaltedHashesAsHex firstObject]];
    } else {
        platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"saltedDomainHash IN %@",preorderSaltedHashesAsHex];
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
    getDocumentsRequest.dataContractId = self.contract.base58ContractID;
    getDocumentsRequest.where = [self whereData];
    if ([self.sortDescriptors count]) {
        getDocumentsRequest.orderBy = [self orderByData];
    }
    getDocumentsRequest.startAt = self.startAt;
    getDocumentsRequest.limit = self.limit;
    DSDLog(@"Sending request to Contract %@",getDocumentsRequest.dataContractId);
    return getDocumentsRequest;
}

@end
