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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const DSStateTransitionModelErrorDomain;

typedef NS_ENUM(NSUInteger, DSStateTransitionModelErrorCode) {
    DSStateTransitionModelErrorCodeSignTransitionFailed = 1,
};

@class DSChainManager, DSBlockchainUser, DPDocument, DPSTPacket, DPContract;

@interface DSDAPIClient : NSObject

@property (readonly, nonatomic, strong) DSChainManager *chainManager;
@property (readonly, nonatomic, strong) DSBlockchainUser *blockchainUser;

- (instancetype)initWithChainManager:(DSChainManager *)chainManager
                      blockchainUser:(DSBlockchainUser *)blockchainUser NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)sendDocument:(DPDocument *)document
            contract:(DPContract *)contract
          completion:(void (^)(NSError *_Nullable error))completion;

- (void)sendPacket:(DPSTPacket *)stPacket
        completion:(void (^)(NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
