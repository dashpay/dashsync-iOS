//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import "DSMessageRequest.h"
#import "DSVersionRequest.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSVersionRequest : DSMessageRequest

@property (nonatomic, readonly) UInt128 address;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) uint32_t protocolVersion;
@property (nonatomic, readonly) uint64_t services;
@property (nonatomic, readonly) uint32_t standardPort;
@property (nonatomic, readonly) uint64_t localNonce;
@property (nonatomic, readonly) NSString *userAgent;

+ (instancetype)requestWithAddress:(UInt128)address
                              port:(uint16_t)port
                   protocolVersion:(uint32_t)protocolVersion
                          services:(uint64_t)services
                      standardPort:(uint32_t)standardPort
                        localNonce:(uint64_t)localNonce
                         userAgent:(NSString *)userAgent;

@end

NS_ASSUME_NONNULL_END
