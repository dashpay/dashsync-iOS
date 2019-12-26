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

#import "DPContractFactory.h"

#import "DPContractFactory+CreateContract.h"
#import "DPSerializeUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPContractFactory ()

@property (strong, nonatomic) id<DPBase58DataEncoder> base58DataEncoder;

@end

@implementation DPContractFactory

- (instancetype)initWithBase58DataEncoder:(id<DPBase58DataEncoder>)base58DataEncoder {
    NSParameterAssert(base58DataEncoder);

    self = [super init];
    if (self) {
        _base58DataEncoder = base58DataEncoder;
    }
    return self;
}

#pragma mark - DPContractFactory

- (DPContract *)contractWithName:(NSString *)name
                       documents:(NSDictionary<NSString *, DPJSONObject *> *)documents {
    NSParameterAssert(name);
    NSParameterAssert(documents);

    NSDictionary *rawContract = @{
        @"name" : name,
        @"documents" : documents,
    };
    DPContract *contract = [self.class dp_contractFromRawContract:rawContract
                                                base58DataEncoder:self.base58DataEncoder];

    return contract;
}

- (nullable DPContract *)contractFromRawContract:(DPJSONObject *)rawContract
                                           error:(NSError *_Nullable __autoreleasing *)error {
    return [self contractFromRawContract:rawContract skipValidation:NO error:error];
}

- (nullable DPContract *)contractFromRawContract:(DPJSONObject *)rawContract
                                  skipValidation:(BOOL)skipValidation
                                           error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(rawContract);

    // TODO: validate rawContract

    DPContract *contract = [self.class dp_contractFromRawContract:rawContract
                                                base58DataEncoder:self.base58DataEncoder];

    return contract;
}

- (nullable DPContract *)contractFromSerialized:(NSData *)data
                                          error:(NSError *_Nullable __autoreleasing *)error {
    return [self contractFromSerialized:data skipValidation:NO error:error];
}

- (nullable DPContract *)contractFromSerialized:(NSData *)data
                                 skipValidation:(BOOL)skipValidation
                                          error:(NSError *_Nullable __autoreleasing *)error {
    NSParameterAssert(data);

    DPJSONObject *rawContract = [DPSerializeUtils decodeSerializedObject:data
                                                                   error:error];
    if (!rawContract) {
        return nil;
    }

    return [self contractFromRawContract:rawContract
                          skipValidation:skipValidation
                                   error:error];
}

@end

NS_ASSUME_NONNULL_END
