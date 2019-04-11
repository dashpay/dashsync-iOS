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

#import "DashPlatformProtocol+DashSync.h"

#import "DSBase58DataEncoder.h"
#import "DSEntropyProvider.h"
#import "DSMerkleRootOperation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DashPlatformProtocol (DashSync)

+ (instancetype)sharedInstance {
    static DashPlatformProtocol *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DSBase58DataEncoder *base58DataEncoder = [[DSBase58DataEncoder alloc] init];
        DSEntropyProvider *entropyProvider = [[DSEntropyProvider alloc] init];
        DSMerkleRootOperation *merkleRootOperation = [[DSMerkleRootOperation alloc] init];
        
        _sharedInstance = [[self alloc] initWithBase58DataEncoder:base58DataEncoder
                                                  entropyProvider:entropyProvider
                                              merkleRootOperation:merkleRootOperation];
    });
    return _sharedInstance;
}

@end

NS_ASSUME_NONNULL_END
