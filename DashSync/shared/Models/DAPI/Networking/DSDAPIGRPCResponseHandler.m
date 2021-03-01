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

#import "DSDAPIGRPCResponseHandler.h"
#import "DPContract.h"
#import "NSData+DSCborDecoding.h"
#import <DAPI-GRPC/Platform.pbobjc.h>
#import <DAPI-GRPC/Platform.pbrpc.h>

@interface DSDAPIGRPCResponseHandler ()

@property (nonatomic, strong) id responseObject;
@property (nonatomic, strong) NSError *decodingError;

@end

@implementation DSDAPIGRPCResponseHandler

- (void)didReceiveInitialMetadata:(nullable NSDictionary *)initialMetadata {
    DSLog(@"didReceiveInitialMetadata");
}

- (void)didReceiveProtoMessage:(nullable GPBMessage *)message {
    if ([message isMemberOfClass:[GetIdentityResponse class]]) {
        GetIdentityResponse *identityResponse = (GetIdentityResponse *)message;
        NSError *error = nil;
        self.responseObject = [[identityResponse identity] ds_decodeCborError:&error];
        if (error) {
            self.decodingError = error;
        }
    } else if ([message isMemberOfClass:[GetDocumentsResponse class]]) {
        GetDocumentsResponse *documentsResponse = (GetDocumentsResponse *)message;
        NSError *error = nil;
        NSMutableArray *mArray = [NSMutableArray array];
        for (NSData *cborData in [documentsResponse documentsArray]) {
            [mArray addObject:[cborData ds_decodeCborError:&error]];
            if (error) break;
        }
        self.responseObject = [mArray copy];
        if (error) {
            self.decodingError = error;
        }
    } else if ([message isMemberOfClass:[GetDataContractResponse class]]) {
        GetDataContractResponse *contractResponse = (GetDataContractResponse *)message;
        NSError *error = nil;
        self.responseObject = [[contractResponse dataContract] ds_decodeCborError:&error];
        if (error) {
            self.decodingError = error;
        }
    } else if ([message isMemberOfClass:[WaitForStateTransitionResultResponse class]]) {
        WaitForStateTransitionResultResponse *waitResponse = (WaitForStateTransitionResultResponse *)message;
        NSError *error = nil;
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        if (([waitResponse responsesOneOfCase] & WaitForStateTransitionResultResponse_Responses_OneOfCase_Proof) > 0) {
            [dictionary setObject:[[waitResponse proof] rootTreeProof] forKey:@"rootTreeProof"];
            [dictionary setObject:[[waitResponse proof] storeTreeProof] forKey:@"storeTreeProof"];
        }
        if (([waitResponse responsesOneOfCase] & WaitForStateTransitionResultResponse_Responses_OneOfCase_Error) > 0) {
            [dictionary setObject:[waitResponse error] forKey:@"platformError"];
        }
        self.responseObject = dictionary;
        if (error) {
            self.decodingError = error;
        }
    }
    DSLog(@"didReceiveProtoMessage");
}

- (void)didCloseWithTrailingMetadata:(nullable NSDictionary *)trailingMetadata
                               error:(nullable NSError *)error {
    NSAssert(self.completionQueue, @"Completion queue must be set");
    if (!error && self.decodingError) {
        error = self.decodingError;
    }
    if (error) {
        if (self.errorHandler) {
            dispatch_async(self.completionQueue, ^{
                self.errorHandler(error);
            });
        }
        DSLog(@"error in didCloseWithTrailingMetadata from IP %@ %@", self.host ? self.host : @"Unknown", error);
        if (self.request) {
            DSLog(@"request contract ID was %@", self.request.contract.base58ContractId);
        }

    } else {
        if (self.successHandler) {
            dispatch_async(self.completionQueue, ^{
                self.successHandler(self.responseObject);
            });
        }
    }
    DSLog(@"didCloseWithTrailingMetadata");
}

- (void)didWriteMessage {
    DSLog(@"didWriteMessage");
}


@end
