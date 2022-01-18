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
#import "DSDocumentTransition.h"
#import "DSMasternodeManager.h"
#import "DSPlatformQuery.h"
#import "DSPlatformRootMerkleTree.h"
#import "DSQuorumEntry.h"
#import "DSTransition.h"
#import "NSData+DSCborDecoding.h"
#import "NSData+DSHash.h"
#import "NSData+DSMerkAVLTree.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"
#import <DAPI-GRPC/Core.pbobjc.h>
#import <DAPI-GRPC/Core.pbrpc.h>
#import <DAPI-GRPC/Platform.pbobjc.h>
#import <DAPI-GRPC/Platform.pbrpc.h>

#define PLATFORM_VERIFY_SIGNATURE 0

@interface DSDAPIGRPCResponseHandler ()

@property (nonatomic, strong) id responseObject;
@property (nonatomic, strong) NSError *decodingError;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) BOOL requireProof;
@property (nonatomic, strong) DSPlatformQuery *query;

@end

@implementation DSDAPIGRPCResponseHandler

- (instancetype)initWithChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [super init];
    if (self) {
        self.chain = chain;
        self.requireProof = requireProof;
    }
    return self;
}

- (instancetype)initForIdentityRequest:(NSData *)identityId withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = [DSPlatformQuery platformQueryForIdentityID:identityId];
    }
    return self;
}

- (instancetype)initForContractRequest:(NSData *)contractId withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = [DSPlatformQuery platformQueryForContractID:contractId];
    }
    return self;
}

- (instancetype)initForStateTransition:(DSTransition *)stateTransition withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (stateTransition.type == DSPlatformDictionary_Documents) {
        DSDocumentTransition *documentTransition = (DSDocumentTransition *)stateTransition;
        self.query = documentTransition.expectedResponseQuery;
    } else {
    }
    return self;
}

- (instancetype)initForDocumentsQueryRequest:(DSPlatformDocumentsRequest *)platformDocumentsRequest withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = platformDocumentsRequest.expectedResponseQuery;
    }
    return self;
}

- (instancetype)initForDocumentsRequest:(NSArray<NSData *> *)documentKeys inPath:(NSArray<NSData *> *)path withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = [DSPlatformQuery platformQueryForIndividualDocumentKeys:documentKeys inPath:path];
    }
    return self;
}

- (instancetype)initForGetIdentityIDsByPublicKeyHashesRequest:(NSArray<NSData *> *)hashes withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = [DSPlatformQuery platformQueryForGetIdentityIDsByPublicKeyHashes:hashes];
    }
    return self;
}

- (instancetype)initForGetIdentitiesByPublicKeyHashesRequest:(NSArray<NSData *> *)hashes withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = [DSPlatformQuery platformQueryForGetIdentitiesByPublicKeyHashes:hashes];
    }
    return self;
}

- (instancetype)initForGetContractsByContractIDs:(NSArray<NSData *> *)contractIDs withChain:(DSChain *)chain requireProof:(BOOL)requireProof {
    self = [self initWithChain:chain requireProof:requireProof];
    if (self) {
        self.query = [DSPlatformQuery platformQueryForGetContractsByContractIDs:contractIDs];
    }
    return self;
}

- (void)parseIdentityMessage:(GetIdentityResponse *)identityResponse {
    NSError *error = nil;
    if (self.requireProof && !identityResponse.hasProof) {
        self.decodingError = [NSError errorWithDomain:@"DashSync"
                                                 code:500
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                          DSLocalizedString(@"Platform returned no proof when we requested it", nil)}];
        return;
    } else if (!self.requireProof && !identityResponse.hasProof) {
		NSData *cborData = identityResponse.identity;
		NSData *identityData = [cborData subdataWithRange:NSMakeRange(4, cborData.length - 4)];
        self.responseObject = [identityData ds_decodeCborError:&error];
    } else {
        Proof *proof = identityResponse.proof;
        ResponseMetadata *metaData = identityResponse.metadata;
        NSDictionary *dictionaries = [self verifyAndExtractFromProof:proof withMetadata:metaData error:&error];
        if (error) {
            self.decodingError = error;
            return;
        }
        NSAssert(dictionaries.count == 1 && [dictionaries objectForKey:@(DSPlatformDictionary_Identities)], @"Dictionary must have 1 internal dictionary corresponding to identities");
        NSDictionary *identitiesDictionary = dictionaries[@(DSPlatformDictionary_Identities)];
        NSAssert(identitiesDictionary.count == 1, @"Identity dictionary must have at most 1 element corresponding to the searched identity");
        id response = [[identitiesDictionary allValues] firstObject];
        if ([response isEqual:@(DSPlatformStoredMessage_NotPresent)]) {
            self.responseObject = nil;
        } else {
            self.responseObject = response;
        }
    }
}

- (void)parseDocumentsMessage:(GetDocumentsResponse *)documentsResponse {
    NSArray *documentsArray = nil;
    NSError *error = nil;
    if (self.requireProof && !documentsResponse.hasProof) {
        self.decodingError = [NSError errorWithDomain:@"DashSync"
                                                 code:500
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                          DSLocalizedString(@"Platform returned no proof when we requested it", nil)}];
    } else if (!self.requireProof && !documentsResponse.hasProof) {
        documentsArray = documentsResponse.documentsArray;
    } else {
        Proof *proof = documentsResponse.proof;
        ResponseMetadata *metaData = documentsResponse.metadata;
        NSError *error = nil;
        NSDictionary *documentsDictionary = [self verifyAndExtractFromProof:proof withMetadata:metaData error:&error];
        if (error) {
            self.decodingError = error;
            return;
        }
        if (documentsDictionary.count == 0) {
            self.responseObject = @[];
            return;
        }

        documentsArray = [documentsDictionary allValues];
    }
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSData *cborData in documentsArray) {
        //uint32_t version = [cborData UInt32AtOffset:0];
        NSData *documentData = [cborData subdataWithRange:NSMakeRange(4, cborData.length - 4)];
        id document = [documentData ds_decodeCborError:&error];
        if (document && !error) {
            [mArray addObject:document];
        }
        if (error) {
            DSLog(@"Decoding error for parseDocumentsMessage cborData %@", cborData);
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
}

- (void)parseDataContractMessage:(GetDataContractResponse *)dataContractResponse {
    NSData *dataContractData = nil;
    NSError *error = nil;
    if (self.requireProof && !dataContractResponse.hasProof) {
        self.decodingError = [NSError errorWithDomain:@"DashSync"
                                                 code:500
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                          DSLocalizedString(@"Platform returned no proof when we requested it", nil)}];
    } else if (!self.requireProof && !dataContractResponse.hasProof) {
        dataContractData = dataContractResponse.dataContract;
    } else {
        Proof *proof = dataContractResponse.proof;
        ResponseMetadata *metaData = dataContractResponse.metadata;
        NSDictionary *dataContractsDictionary = [self verifyAndExtractFromProof:proof withMetadata:metaData error:&error];
        if (error) {
            self.decodingError = error;
            return;
        }
        if (dataContractsDictionary.count == 0) {
            self.responseObject = nil;
            return;
        }
        dataContractData = dataContractsDictionary.allValues[0];
    }
    self.responseObject = [dataContractData ds_decodeCborError:&error];
    if (error) {
        DSLog(@"Decoding error for parseDataContractMessage cborData %@", dataContractData);
        self.decodingError = error;
    }
}

- (void)parseWaitForStateTransitionResultMessage:(WaitForStateTransitionResultResponse *)waitResponse {
    NSArray *documentsArray = nil;
    StateTransitionBroadcastError *broadcastError = nil;
    if (([waitResponse responsesOneOfCase] & WaitForStateTransitionResultResponse_Responses_OneOfCase_Error) > 0) {
        broadcastError = [waitResponse error];
    }

    BOOL hasProof = (([waitResponse responsesOneOfCase] & WaitForStateTransitionResultResponse_Responses_OneOfCase_Proof) > 0);

    if (self.requireProof && !hasProof) {
        self.decodingError = [NSError errorWithDomain:@"DashSync"
                                                 code:500
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                          DSLocalizedString(@"Platform returned no proof when we requested it", nil)}];
    } else if (!self.requireProof && !hasProof) {
        // In this case just assume things went well if there's no error
        if (broadcastError) {
            self.decodingError = [NSError errorWithDomain:@"DashPlatform"
                                                     code:broadcastError.code
                                                 userInfo:@{NSLocalizedDescriptionKey: broadcastError.message}];
        } else {
            self.responseObject = @[]; //Todo
        }
    } else {
        Proof *proof = waitResponse.proof;
        ResponseMetadata *metaData = waitResponse.metadata;
        NSError *error = nil;
        NSDictionary *documentsDictionary = [self verifyAndExtractFromProof:proof withMetadata:metaData error:&error];
        if (error) {
            self.decodingError = error;
            return;
        }
        if (documentsDictionary.count == 0) {
            self.responseObject = @[];
            return;
        }

        documentsArray = [documentsDictionary allValues];

        NSMutableArray *mArray = [NSMutableArray array];
        for (NSData *cborData in documentsArray) {
            id document = [cborData ds_decodeCborError:&error];
            if (document && !error) {
                [mArray addObject:document];
            }
            if (error) {
                DSLog(@"Decoding error for parseDocumentsMessage cborData %@", cborData);
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
    }
}

- (void)parseGetIdentitiesByPublicKeyHashesMessage:(GetIdentitiesByPublicKeyHashesResponse *)getIdentitiesResponse {
    NSAssert(self.chain, @"The chain must be set");
    NSMutableArray *identityDictionaries = [NSMutableArray array];


    if (self.requireProof && !getIdentitiesResponse.hasProof) {
        self.decodingError = [NSError errorWithDomain:@"DashSync"
                                                 code:500
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                          DSLocalizedString(@"Platform returned no proof when we requested it", nil)}];
    } else if (!self.requireProof && !getIdentitiesResponse.hasProof) {
        NSError *error = nil;

        for (NSData *cborData in getIdentitiesResponse.identitiesArray) {
            if (!cborData.length) continue;
			NSData *identityData = [cborData subdataWithRange:NSMakeRange(4, cborData.length - 4)];
            NSDictionary *identityDictionary = [identityData ds_decodeCborError:&error];
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
    } else {
        Proof *proof = getIdentitiesResponse.proof;
        ResponseMetadata *metaData = getIdentitiesResponse.metadata;

        NSError *error = nil;
        NSDictionary *identitiesDictionaries = [self verifyAndExtractFromProof:proof withMetadata:metaData error:&error];
        if (error) {
            self.decodingError = error;
            return;
        }
        NSAssert(identitiesDictionaries.count == 2, @"Identities dictionary must have 2 internal dictionaries");
        NSDictionary *identitiesDictionary = identitiesDictionaries[@(DSPlatformDictionary_Identities)];
        if (identitiesDictionary.count == 0) {
            self.responseObject = @[];
            return;
        }
        self.responseObject = [[identitiesDictionary allValues] copy];
        if (error) {
            self.decodingError = error;
        }
    }
}

- (void)parseGetIdentityIdsByPublicKeyHashesMessage:(GetIdentityIdsByPublicKeyHashesResponse *)getIdentitiesResponse {
    NSAssert(self.chain, @"The chain must be set");
    //    GetIdentityIdsByPublicKeyHashesResponse *identitiesByPublicKeyHashesResponse = (GetIdentityIdsByPublicKeyHashesResponse *)message;
    NSMutableArray *identityDictionaries = [NSMutableArray array];
    //    Proof *proof = identitiesByPublicKeyHashesResponse.proof;
    //    ResponseMetadata *metaData = identitiesByPublicKeyHashesResponse.metadata;
    NSError *error = nil;
    //        NSDictionary *identitiesDictionary = [self verifyAndExtractFromProof:proof withMetadata:metaData error:&error];
    //        if (error) {
    //            self.decodingError = error;
    //            return;
    //        }

    for (NSData *data in getIdentitiesResponse.identityIdsArray) {
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

- (void)didReceiveInitialMetadata:(nullable NSDictionary *)initialMetadata {
    DSLog(@"didReceiveInitialMetadata");
}

- (void)didReceiveProtoMessage:(nullable GPBMessage *)message {
    if ([message isMemberOfClass:[GetIdentityResponse class]]) {
        [self parseIdentityMessage:(GetIdentityResponse *)message];
    } else if ([message isMemberOfClass:[GetDocumentsResponse class]]) {
        [self parseDocumentsMessage:(GetDocumentsResponse *)message];
    } else if ([message isMemberOfClass:[GetDataContractResponse class]]) {
        [self parseDataContractMessage:(GetDataContractResponse *)message];
    } else if ([message isMemberOfClass:[WaitForStateTransitionResultResponse class]]) {
        [self parseWaitForStateTransitionResultMessage:(WaitForStateTransitionResultResponse *)message];
    } else if ([message isMemberOfClass:[GetIdentitiesByPublicKeyHashesResponse class]]) {
        [self parseGetIdentitiesByPublicKeyHashesMessage:(GetIdentitiesByPublicKeyHashesResponse *)message];
    } else if ([message isMemberOfClass:[GetIdentityIdsByPublicKeyHashesResponse class]]) {
        [self parseGetIdentityIdsByPublicKeyHashesMessage:(GetIdentityIdsByPublicKeyHashesResponse *)message];
    } else if ([message isMemberOfClass:[GetTransactionResponse class]]) {
        GetTransactionResponse *transactionResponse = (GetTransactionResponse *)message;
        NSError *error = nil;
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setObject:[transactionResponse transaction] forKey:@"transactionData"];
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

- (NSDictionary *)verifyAndExtractFromProof:(Proof *)proof withMetadata:(ResponseMetadata *)metaData error:(NSError **)error {
    return [DSDAPIGRPCResponseHandler verifyAndExtractFromProof:proof withMetadata:metaData query:self.query onChain:self.chain error:error];
}

+ (NSDictionary *)verifyAndExtractFromProof:(Proof *)proof withMetadata:(ResponseMetadata *)metaData query:(DSPlatformQuery *)query onChain:(DSChain *)chain error:(NSError **)error {
    NSData *quorumHashData = proof.signatureLlmqHash;
    if (!quorumHashData) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Platform returned no quorum hash data", nil)}];
    }
    UInt256 quorumHash = quorumHashData.reverse.UInt256;
    if (uint256_is_zero(quorumHash)) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Platform returned an empty quorum hash", nil)}];
    }
    DSQuorumEntry *quorumEntry = [chain.chainManager.masternodeManager quorumEntryForPlatformHavingQuorumHash:quorumHash forBlockHeight:metaData.coreChainLockedHeight];
    if (quorumEntry && quorumEntry.verified) {
        return [self verifyAndExtractFromProof:proof withMetadata:metaData query:query forQuorumEntry:quorumEntry quorumType:chain.quorumTypeForPlatform error:error];
    } else if (quorumEntry) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:400
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Quorum entry %@ found but is not yet verified", nil)}];
        DSLog(@"quorum entry %@ found but is not yet verified", uint256_hex(quorumEntry.quorumHash));
    } else {
        DSLog(@"no quorum entry found for quorum hash %@", uint256_hex(quorumHash));
    }
    return nil;
}

+ (NSDictionary *)verifyAndExtractFromProof:(Proof *)proof withMetadata:(ResponseMetadata *)metaData query:(DSPlatformQuery *)query forQuorumEntry:(DSQuorumEntry *)quorumEntry quorumType:(DSLLMQType)quorumType error:(NSError **)error {
    NSData *signatureData = proof.signature;
    if (!signatureData) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Platform returned no signature data", nil)}];
        return nil;
    }
    UInt768 signature = signatureData.UInt768;
    if (uint256_is_zero(signature)) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Platform returned an empty or wrongly sized signature", nil)}];
        return nil;
    }

    // We first need to get the merk Root

    NSDictionary *identitiesDictionary = nil;
    NSDictionary *documentsDictionary = nil;
    NSDictionary *contractsDictionary = nil;
    NSDictionary *publicKeyHashesToIdentityIdsProofDictionary = nil;
    StoreTreeProofs *proofs = proof.storeTreeProofs;

    NSData *identitiesRoot = nil;
    NSData *documentsRoot = nil;
    NSData *contractsRoot = nil;
    NSData *publicKeyHashesToIdentityIdsRoot = nil;

    NSMutableDictionary<NSNumber *, NSData *> *rootElementsToProve = [NSMutableDictionary dictionary];

    if (proofs.identitiesProof.length > 0) {
        DSPlatformTreeQuery *treeQuery = [query treeQueryForType:DSPlatformDictionary_Identities];
        identitiesRoot = [proofs.identitiesProof executeProofReturnElementDictionary:&identitiesDictionary query:treeQuery decode:TRUE usesVersion:TRUE error:error];
        if (*error) {
            return nil;
        }
        if (!treeQuery) {
            DSPlatformTreeQuery *treeQueryForPublicKeyHashesToIdentityIds = [query treeQueryForType:DSPlatformDictionary_PublicKeyHashesToIdentityIds];
            if (treeQueryForPublicKeyHashesToIdentityIds) {
                NSMutableArray *identitiesWithoutVersions = [NSMutableArray array];
                for (NSDictionary *identityDictionaryWithVersion in [identitiesDictionary allValues]) {
					if([identityDictionaryWithVersion respondsToSelector:@selector(objectForKey:)]) {
						[identitiesWithoutVersions addObject:[identityDictionaryWithVersion objectForKey:@(DSPlatformStoredMessage_Item)]];
					}
                }
                BOOL verified = [query verifyPublicKeyHashesForIdentityDictionaries:identitiesWithoutVersions];
                if (!verified) {
                    *error = [NSError errorWithDomain:@"DashSync"
                                                 code:500
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                          DSLocalizedString(@"Platform returned a proof that does not satisfy our query", nil)}];
                    return nil;
                }
            }
        }
        [rootElementsToProve setObject:identitiesRoot forKey:@(DSPlatformDictionary_Identities)];
    }

    if (proofs.publicKeyHashesToIdentityIdsProof.length > 0) {
        DSPlatformTreeQuery *treeQuery = [query treeQueryForType:DSPlatformDictionary_PublicKeyHashesToIdentityIds];
        publicKeyHashesToIdentityIdsRoot = [proofs.publicKeyHashesToIdentityIdsProof executeProofReturnElementDictionary:&publicKeyHashesToIdentityIdsProofDictionary query:treeQuery decode:FALSE usesVersion:FALSE error:error];
        if (*error) {
            return nil;
        }
        [rootElementsToProve setObject:publicKeyHashesToIdentityIdsRoot forKey:@(DSPlatformDictionary_PublicKeyHashesToIdentityIds)];
    }

    if (proofs.documentsProof.length > 0) {
        DSPlatformTreeQuery *treeQuery = [query treeQueryForType:DSPlatformDictionary_Documents];
        documentsRoot = [proofs.documentsProof executeProofReturnElementDictionary:&documentsDictionary query:treeQuery decode:TRUE usesVersion:TRUE error:error];
        if (*error) {
            return nil;
        }
        [rootElementsToProve setObject:documentsRoot forKey:@(DSPlatformDictionary_Documents)];
    }

    if (proofs.dataContractsProof.length > 0) {
        DSPlatformTreeQuery *treeQuery = [query treeQueryForType:DSPlatformDictionary_Contracts];
        contractsRoot = [proofs.dataContractsProof executeProofReturnElementDictionary:&contractsDictionary query:treeQuery decode:TRUE usesVersion:TRUE error:error];
        if (*error) {
            return nil;
        }
        [rootElementsToProve setObject:contractsRoot forKey:@(DSPlatformDictionary_Contracts)];
    }

    DSPlatformRootMerkleTree *merkleTree = [DSPlatformRootMerkleTree merkleTreeWithElementsToProve:rootElementsToProve proofData:proof.rootTreeProof hashFunction:DSMerkleTreeHashFunction_BLAKE3 fixedElementCount:6];

    UInt256 stateHash = merkleTree.merkleRoot;
    if (uint256_is_zero(stateHash)) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Platform returned an incorrect rootTreeProof", nil)}];
        return nil;
    }


#if PLATFORM_VERIFY_SIGNATURE
    NSMutableData *stateData = [NSMutableData data];
    [stateData appendInt64:metaData.height - 1];
    [stateData appendUInt256:stateHash];
    UInt256 stateMessageHash = [stateData SHA256];
    BOOL signatureVerified = [self verifyStateSignature:signature forStateMessageHash:stateMessageHash height:metaData.height - 1 againstQuorum:quorumEntry quorumType:quorumType];
    if (!signatureVerified) {
        *error = [NSError errorWithDomain:@"DashSync"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey:
                                              DSLocalizedString(@"Platform returned an empty or wrongly sized signature", nil)}];
        DSLog(@"unable to verify platform signature");
        return nil;
    }
#endif

    NSMutableDictionary *elementsDictionary = [NSMutableDictionary dictionary];
    if (identitiesDictionary) {
        [elementsDictionary setObject:identitiesDictionary forKey:@(DSPlatformDictionary_Identities)];
    }
    if (documentsDictionary) {
        [elementsDictionary setObject:documentsDictionary forKey:@(DSPlatformDictionary_Documents)];
    }
    if (contractsDictionary) {
        [elementsDictionary setObject:contractsDictionary forKey:@(DSPlatformDictionary_Contracts)];
    }
    if (publicKeyHashesToIdentityIdsProofDictionary) {
        [elementsDictionary setObject:publicKeyHashesToIdentityIdsProofDictionary forKey:@(DSPlatformDictionary_PublicKeyHashesToIdentityIds)];
    }

    return elementsDictionary;
}

+ (UInt256)requestIdForHeight:(int64_t)height {
    NSMutableData *data = [NSMutableData data];
    [data appendBytes:@"dpsvote".UTF8String length:7];
    [data appendUInt64:height];
    return [data SHA256];
}

+ (UInt256)signIDForQuorumEntry:(DSQuorumEntry *)quorumEntry quorumType:(DSLLMQType)quorumType forStateMessageHash:(UInt256)stateMessageHash height:(int64_t)height {
    UInt256 requestId = [self requestIdForHeight:height];
    NSMutableData *data = [NSMutableData data];
    [data appendUInt8:quorumType];
    [data appendUInt256:quorumEntry.quorumHash];
    [data appendUInt256:uint256_reverse(requestId)];
    [data appendUInt256:uint256_reverse(stateMessageHash)];
    return [data SHA256_2];
}

+ (BOOL)verifyStateSignature:(UInt768)signature forStateMessageHash:(UInt256)stateMessageHash height:(int64_t)height againstQuorum:(DSQuorumEntry *)quorumEntry quorumType:(DSLLMQType)quorumType {
    UInt384 publicKey = quorumEntry.quorumPublicKey;
    DSBLSKey *blsKey = [DSBLSKey keyWithPublicKey:publicKey];
    UInt256 signId = [self signIDForQuorumEntry:quorumEntry quorumType:quorumType forStateMessageHash:stateMessageHash height:height];
    DSLogPrivate(@"verifying DAPI returned signature %@ with public key %@ against quorum %@", [NSData dataWithUInt768:signature].hexString, [NSData dataWithUInt384:publicKey].hexString, quorumEntry);
    return [blsKey verify:signId signature:signature];
}


@end
