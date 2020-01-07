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

#import "DPContractFacade.h"

#import "DPContractFactory.h"

NS_ASSUME_NONNULL_BEGIN

@interface DPContractFacade ()

@property (strong, nonatomic) DPContractFactory *factory;

@end

@implementation DPContractFacade

- (instancetype)init {

    self = [super init];
    if (self) {
        _factory = [[DPContractFactory alloc] init];
    }
    return self;
}

- (DPContract *)contractWithName:(NSString *)name
                       documents:(NSDictionary<NSString *, DSStringValueDictionary *> *)documents {
    return [self.factory contractWithName:name documents:documents];
}

- (nullable DPContract *)contractFromRawContract:(DSStringValueDictionary *)rawContract
                                           error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory contractFromRawContract:rawContract error:error];
}

- (nullable DPContract *)contractFromRawContract:(DSStringValueDictionary *)rawContract
                                  skipValidation:(BOOL)skipValidation
                                           error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory contractFromRawContract:rawContract skipValidation:skipValidation error:error];
}

- (nullable DPContract *)contractFromSerialized:(NSData *)data
                                          error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory contractFromSerialized:data error:error];
}

- (nullable DPContract *)contractFromSerialized:(NSData *)data
                                 skipValidation:(BOOL)skipValidation
                                          error:(NSError *_Nullable __autoreleasing *)error {
    return [self.factory contractFromSerialized:data skipValidation:skipValidation error:error];
}

@end

NS_ASSUME_NONNULL_END
