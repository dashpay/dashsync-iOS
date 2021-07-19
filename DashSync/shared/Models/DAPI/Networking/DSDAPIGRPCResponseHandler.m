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
#import "DSBLSKey.h"
#import "DSChain.h"
#import "DSChainManager.h"
#import "DSMasternodeManager.h"
#import "DSMerkleTree.h"
#import "DSQuorumEntry.h"
#import "NSData+Bitcoin.h"
#import "NSData+DSCborDecoding.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import <DAPI-GRPC/Core.pbobjc.h>
#import <DAPI-GRPC/Core.pbrpc.h>
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
        NSData *identityData = [identityResponse identity];
        if (identityData.length == 0) {
            // This should eventually mean that there's no identity, but for now this is not expected
            self.responseObject = [identityData ds_decodeCborError:&error];
            if (error) {
                self.decodingError = error;
            }
        } else {
            self.responseObject = [identityData ds_decodeCborError:&error];
            if (error) {
                self.decodingError = error;
            }
        }
    } else if ([message isMemberOfClass:[GetDocumentsResponse class]]) {
        GetDocumentsResponse *documentsResponse = (GetDocumentsResponse *)message;
        NSError *error = nil;
        NSMutableArray *mArray = [NSMutableArray array];
        for (NSData *cborData in [documentsResponse documentsArray]) {
            id document = [cborData ds_decodeCborError:&error];
            if (document && !error) {
                [mArray addObject:document];
            }
            if (error) {
                NSLog(@"Decoding error for cborData %@", cborData);
                if (self.request) {
                    DSLog(@"request was %@", self.request.predicate);
                }
                break;
            }
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
    } else if ([message isMemberOfClass:[GetTransactionResponse class]]) {
        GetTransactionResponse *transactionResponse = (GetTransactionResponse *)message;
        NSError *error = nil;
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setObject:[transactionResponse transaction] forKey:@"transactionData"];
        self.responseObject = dictionary;
        if (error) {
            self.decodingError = error;
        }
    } else if ([message isMemberOfClass:[GetIdentitiesByPublicKeyHashesResponse class]]) {
        NSAssert(self.chain, @"The chain must be set");
        GetIdentitiesByPublicKeyHashesResponse *identitiesByPublicKeyHashesResponse = (GetIdentitiesByPublicKeyHashesResponse *)message;
        NSMutableArray *identityDictionaries = [NSMutableArray array];
        Proof *proof = identitiesByPublicKeyHashesResponse.proof;
        ResponseMetadata *metaData = identitiesByPublicKeyHashesResponse.metadata;
        NSError *error = [self verifyProof:proof withMetadata:metaData];
        if (error) {
            self.decodingError = error;
            return;
        }

        for (NSData *data in identitiesByPublicKeyHashesResponse.identitiesArray) {
            if (!data.length) continue;
            NSDictionary *identityDictionary = [data ds_decodeCborError:&error];
            if (error) {
                self.decodingError = error;
                return;
            }
            NSData *identityIdData = [identityDictionary objectForKey:@"id"];
            UInt256 identityId = identityIdData.UInt256;
            if (uint256_is_zero(identityId)) {
                self.decodingError = [NSError errorWithDomain:@"DashSync"
                                                         code:500
                                                     userInfo:@{NSLocalizedDescriptionKey:
                                                                  DSLocalizedString(@"Platform returned an incorrect value as an identity ID", nil)}];
                return;
            }
            [identityDictionaries addObject:identityDictionary];
        }
        self.responseObject = identityDictionaries;
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

- (NSError *)verifyProof:(Proof *)proof withMetadata:(ResponseMetadata *)metaData {
    NSData *quorumHashData = proof.signatureLlmqHash;
    if (!quorumHashData) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:500
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Platform returned no quorum hash data", nil)}];
    }
    UInt256 quorumHash = quorumHashData.UInt256;
    if (uint256_is_zero(quorumHash)) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:500
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Platform returned an empty quorum hash", nil)}];
    }
    NSData *signatureData = proof.signature;
    if (!signatureData) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:500
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Platform returned no signature data", nil)}];
    }
    UInt768 signature = signatureData.UInt768;
    if (uint256_is_zero(signature)) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:500
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Platform returned an empty or wrongly sized signature", nil)}];
    }
    DSMerkleTree *merkleTree = [DSMerkleTree merkleTreeWithData:proof.rootTreeProof treeElementCount:3 hashFunction:DSMerkleTreeHashFunction_BLAKE2b_160];
    UInt256 stateHash = merkleTree.merkleRoot;
    if (uint256_is_zero(stateHash)) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:500
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Platform returned an incorrect rootTreeProof", nil)}];
    }
    DSQuorumEntry *quorumEntry = [self.chain.chainManager.masternodeManager quorumEntryForPlatformHavingQuorumHash:quorumHash forBlockHeight:metaData.coreChainLockedHeight];
    if (quorumEntry && quorumEntry.verified) {
        //Todo get the stateId
        BOOL signatureVerified = [self verifySignature:signature withStateId:stateHash height:metaData.height againstQuorum:quorumEntry];
        if (!signatureVerified) {
            DSLog(@"unable to verify platform signature");
        } else {
            DSLog(@"platform signature verified");
        }
    } else if (quorumEntry) {
        return [NSError errorWithDomain:@"DashSync"
                                   code:400
                               userInfo:@{NSLocalizedDescriptionKey:
                                            DSLocalizedString(@"Quorum entry %@ found but is not yet verified", nil)}];
        DSLog(@"quorum entry %@ found but is not yet verified", uint256_hex(quorumEntry.quorumHash));
    } else {
        DSLog(@"no quorum entry found");
    }
    return nil;
}

- (UInt256)requestIdForHeight:(int64_t)height {
    NSMutableData *data = [NSMutableData data];
    [data appendString:@"dpsvote"];
    [data appendUInt64:height];
    return [data SHA256_2];
}

- (UInt256)signIDForQuorumEntry:(DSQuorumEntry *)quorumEntry withStateId:(UInt256)stateId height:(int64_t)height {
    UInt256 requestId = [self requestIdForHeight:height];
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.chain.quorumTypeForPlatform];
    [data appendUInt256:quorumEntry.quorumHash];
    [data appendUInt256:requestId];
    [data appendUInt256:stateId];
    return [data SHA256_2];
}

- (BOOL)verifySignature:(UInt768)signature withStateId:(UInt256)stateId height:(int64_t)height againstQuorum:(DSQuorumEntry *)quorumEntry {
    UInt384 publicKey = quorumEntry.quorumPublicKey;
    DSBLSKey *blsKey = [DSBLSKey keyWithPublicKey:publicKey];
    UInt256 signId = [self signIDForQuorumEntry:quorumEntry withStateId:stateId height:height];
    DSLogPrivate(@"verifying DAPI returned signature %@ with public key %@ against quorum %@", [NSData dataWithUInt768:signature].hexString, [NSData dataWithUInt384:publicKey].hexString, quorumEntry);
    return [blsKey verify:signId signature:signature];
}


@end
