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
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import <DAPI-GRPC/Platform.pbrpc.h>
#import <DAPI-GRPC/Platform.pbobjc.h>
#import "DPContract.h"
#import "NSPredicate+CBORData.h"

@implementation DSPlatformDocumentsRequest

-(instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

+(instancetype)dpnsRequestForName:(NSString*)name {
    DSPlatformDocumentsRequest * platformDocumentsRequest = [DSPlatformDocumentsRequest init];
    //UInt256 hashOfName = [[name dataUsingEncoding:NSUTF8StringEncoding] SHA256_2];
    platformDocumentsRequest.predicate = [NSPredicate predicateWithFormat:@"normalizedLabel == %@ && normalizedParentDomainName == dash",name];
    platformDocumentsRequest.startAt = 0;
    platformDocumentsRequest.limit = 1;
    platformDocumentsRequest.type = DSPlatformDocumentType_Document;
    return platformDocumentsRequest;
}

-(GetDocumentsRequest*)getDocumentsRequest {
    GetDocumentsRequest * getDocumentsRequest = [[GetDocumentsRequest alloc] init];
    getDocumentsRequest.documentType = @"1";
    getDocumentsRequest.dataContractId = DPNS_ID;
    getDocumentsRequest.where = [self.predicate dashPlatormWhereDataWithStartAt:@(self.startAt) limit:@(self.limit)];
    return getDocumentsRequest;
}

@end
