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

#import "DSDAPINetworkServiceProtocol.h"
#import <DAPI-GRPC/Platform.pbobjc.h>
#import <DAPI-GRPC/Platform.pbrpc.h>

NS_ASSUME_NONNULL_BEGIN

@class HTTPLoaderFactory, DSChain;

@interface DSDAPINetworkService : NSObject <DSDAPINetworkServiceProtocol>

@property (readonly, nonatomic) NSString *ipAddress;

- (instancetype)initWithDAPINodeIPAddress:(NSString *)ipAddress httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory usingGRPCDispatchQueue:(dispatch_queue_t)grpcDispatchQueue onChain:(DSChain *)chain NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
