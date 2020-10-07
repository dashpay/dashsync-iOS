//  
//  Created by Andrew Podkovyrin
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

#import "DSAccountEntity6To7MigrationPolicy.h"

#import "DSAccountEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"

@implementation DSAccountEntity6To7MigrationPolicy

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError *__autoreleasing  _Nullable *)error {
    BOOL result = [super createRelationshipsForDestinationInstance:dInstance entityMapping:mapping manager:manager error:error];
    
    DSAccountEntity *account = (DSAccountEntity *)dInstance;
    DSDerivationPathEntity *derivationPath = account.derivationPaths.anyObject;
    if (derivationPath != nil) {
        account.chain = derivationPath.chain;
    }
    else {
        NSAssert(NO, @"This is not possible");
    }
    
    return result;
}

@end
