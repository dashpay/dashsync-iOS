//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DPDocumentFactory.h"
#import "DPDocument.h"
#import "DPErrors.h"

#import "BigIntTypes.h"
#import "DSKey.h"
#import "NSData+Dash.h"
#import <TinyCborObjc/NSData+DSCborDecoding.h>

NS_ASSUME_NONNULL_BEGIN

//static NSInteger const DEFAULT_REVISION = 1;

@interface DPDocumentFactory ()

@property (assign, nonatomic) UInt256 userId;
@property (strong, nonatomic) DPContract *contract;
@property (strong, nonatomic) DSChain *chain;

@end

@implementation DPDocumentFactory

- (instancetype)initWithBlockchainIdentity:(DSBlockchainIdentity *)identity
                                  contract:(DPContract *)contract
                                   onChain:(DSChain *)chain {
    NSParameterAssert(identity);
    NSParameterAssert(contract);

    self = [super init];
    if (self) {
        _userId = identity.uniqueID;
        _contract = contract;
        _chain = chain;
    }
    return self;
}

#pragma mark - DPDocumentFactory

- (nullable DPDocument *)documentOnTable:(NSString *)tableName
                      withDataDictionary:(nullable DSStringValueDictionary *)dataDictionary
                            usingEntropy:(NSData *)entropy
                                   error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(tableName);

    if (!dataDictionary) {
        dataDictionary = @{};
    }

    if (uint256_is_zero(self.contract.contractId) && uint256_is_zero(self.contract.registeredBlockchainIdentityUniqueID)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_InvalidDocumentType
                                     userInfo:@{
                                         NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:DSLocalizedString(@"Contract '%@' needs to first be locally registered or known", nil),
                                                       self.contract.name],
                                     }];
        }

        return nil;
    }

    if (![self.contract isDocumentDefinedForType:tableName]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_UnknownContract
                                     userInfo:@{
                                         NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:DSLocalizedString(@"Contract '%@' doesn't contain a table named '%@'", nil),
                                                       self.contract.name, tableName],
                                     }];
        }

        return nil;
    }

    DPDocument *object = [[DPDocument alloc] initWithDataDictionary:dataDictionary createdByUserWithId:self.userId onContractWithId:self.contract.contractId onTableWithName:tableName usingEntropy:entropy];

    return object;
}

- (nullable DPDocument *)documentOnTable:(NSString *)tableName
                      withDataDictionary:(nullable DSStringValueDictionary *)dataDictionary
                 usingDocumentIdentifier:(NSData *)identifier
                                   error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(tableName);

    if (!dataDictionary) {
        dataDictionary = @{};
    }

    if (uint256_is_zero(self.contract.contractId) && uint256_is_zero(self.contract.registeredBlockchainIdentityUniqueID)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_InvalidDocumentType
                                     userInfo:@{
                                         NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:DSLocalizedString(@"Contract '%@' needs to first be locally registered or known", nil),
                                                       self.contract.name],
                                     }];
        }

        return nil;
    }

    if (![self.contract isDocumentDefinedForType:tableName]) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:DPErrorDomain
                                         code:DPErrorCode_UnknownContract
                                     userInfo:@{
                                         NSLocalizedDescriptionKey:
                                             [NSString stringWithFormat:DSLocalizedString(@"Contract '%@' doesn't contain a table named '%@'", nil),
                                                       self.contract.name, tableName],
                                     }];
        }

        return nil;
    }

    DPDocument *object = [[DPDocument alloc] initWithDataDictionary:dataDictionary createdByUserWithId:self.userId onContractWithId:self.contract.contractId onTableWithName:tableName usingDocumentId:identifier.UInt256];

    return object;
}

@end

NS_ASSUME_NONNULL_END
