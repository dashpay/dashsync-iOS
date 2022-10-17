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

#import "DSGetGovernanceObjectsRequest.h"
#import "DSPeer.h"
#import "NSCoder+Dash.h"
#import "NSMutableData+Dash.h"

@implementation DSGetGovernanceObjectsRequest

+ (instancetype)requestWithGovernanceObjectHashes:(NSArray<NSData *> *)hashes {
    return [[DSGetGovernanceObjectsRequest alloc] initWithHashes:hashes];
}

- (NSString *)description {
    return @"governance objects";
}

- (uint32_t)invType {
    return DSInvType_GovernanceObject;
}


@end
