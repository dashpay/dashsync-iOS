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

#import "DSTransientDashpayUser+Protected.h"

@implementation DSTransientDashpayUser

- (instancetype)initWithDashpayProfileDocument:(NSDictionary *)profileDocument {
    self = [super init];
    if (self) {
        self.revision = [[profileDocument objectForKey:@"$revision"] intValue];
        self.avatarPath = [profileDocument objectForKey:@"avatarUrl"];
        self.avatarFingerprint = [profileDocument objectForKey:@"avatarFingerprint"];
        self.avatarHash = [profileDocument objectForKey:@"avatarHash"];
        self.publicMessage = [profileDocument objectForKey:@"publicMessage"];
        self.displayName = [profileDocument objectForKey:@"displayName"];
        self.createdAt = [[profileDocument objectForKey:@"$createdAt"] unsignedLongValue];
        self.updatedAt = [[profileDocument objectForKey:@"$updatedAt"] unsignedLongValue];
        self.documentIdentifier = [profileDocument objectForKey:@"$id"];
    }
    return self;
}

@end
