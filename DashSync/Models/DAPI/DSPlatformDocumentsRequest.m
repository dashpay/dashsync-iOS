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

@implementation DSPlatformDocumentsRequest

-(instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

+(instancetype)dpnsRequestForUsername:(NSString*)username {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    //UInt256 hashOfName = [[name dataUsingEncoding:NSUTF8StringEncoding] SHA256_2];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel == %@ && normalizedParentDomainName == dash",username];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForUsernames:(NSArray*)usernames {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    //UInt256 hashOfName = [[name dataUsingEncoding:NSUTF8StringEncoding] SHA256_2];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel IN %@ && normalizedParentDomainName == dash",usernames];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = (uint32_t)usernames.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    return platformDocumentsRequest;
}

+(instancetype)dpnsRequestForPreorderSaltedHashes:(NSArray*)preorderSaltedHashes {
    NSMutableArray * preorderSaltedHashesAsHex = [NSMutableArray array];
    for (NSData* data in preorderSaltedHashes) {
        [preorderSaltedHashesAsHex addObject:data.hexString];
    }
    DSPlatformDocumentsRequest * platformDocumentsRequest = [[DSPlatformDocumentsRequest alloc] init];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"preorderSaltedHash IN %@",preorderSaltedHashesAsHex];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = (uint32_t)preorderSaltedHashes.count;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
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
    GetDocumentsRequest * getDocumentsRequest = [[GetDocumentsRequest alloc] init];
    getDocumentsRequest.documentType = @"domain";
    getDocumentsRequest.dataContractId = DPNS_ID;
    getDocumentsRequest.where = [self whereData];
    getDocumentsRequest.orderBy = [self orderByData];
    getDocumentsRequest.startAt = self.startAt;
    getDocumentsRequest.limit = self.limit;
    return getDocumentsRequest;
}

@end
