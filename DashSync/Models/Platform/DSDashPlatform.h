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

#import "DPContractFactoryProtocol.h"
#import "DPDocumentFactoryProtocol.h"
#import "DPSTPacketFactoryProtocol.h"
#import "DPSTPacketHeaderFactoryProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSDashPlatform : NSObject

@property (nullable, copy, nonatomic) NSString *userId;
@property (nullable, strong, nonatomic) DPContract *contract;

@property (readonly, strong, nonatomic) id<DPContractFactory> contractFactory;
@property (readonly, strong, nonatomic) id<DPDocumentFactory> documentFactory;
@property (readonly, strong, nonatomic) id<DPSTPacketFactory> stPacketFactory;
@property (readonly, strong, nonatomic) id<DPSTPacketHeaderFactory> stPacketHeaderFactory;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedInstanceForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
