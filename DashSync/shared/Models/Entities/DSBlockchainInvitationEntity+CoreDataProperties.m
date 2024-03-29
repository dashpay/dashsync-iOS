//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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
//

#import "DSBlockchainInvitationEntity+CoreDataProperties.h"

@implementation DSBlockchainInvitationEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainInvitationEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSBlockchainInvitationEntity"];
}

@dynamic link;
@dynamic name;
@dynamic tag;
@dynamic chain;
@dynamic blockchainIdentity;

@end
