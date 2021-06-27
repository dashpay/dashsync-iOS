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

#import "DSPlatformDocumentsRequest.h"
#import <DAPI-GRPC/Platform.pbobjc.h>
#import <DAPI-GRPC/Platform.pbrpc.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain;

@interface DSDAPIGRPCResponseHandler : NSObject <GRPCProtoResponseHandler>

@property (atomic, strong) dispatch_queue_t dispatchQueue;
@property (atomic, strong) dispatch_queue_t completionQueue;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSString *host;                      //for debuging purposes
@property (nonatomic, strong) DSPlatformDocumentsRequest *request; //for debuging purposes

@property (nonatomic, copy) void (^successHandler)(id successObject);
@property (nonatomic, copy) void (^errorHandler)(NSError *error);

@end

NS_ASSUME_NONNULL_END
