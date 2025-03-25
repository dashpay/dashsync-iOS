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

#import "DSKeyManager.h"
#import "DSTransientDashpayUser+Protected.h"

@implementation DSTransientDashpayUser

- (instancetype)initWithDashpayProfileDocument:(NSDictionary *)profileDocument {
    self = [super init];
    if (self) {
        self.revision = [profileDocument[@"$revision"] intValue];
        self.avatarPath = profileDocument[@"avatarUrl"];
        self.avatarFingerprint = profileDocument[@"avatarFingerprint"];
        self.avatarHash = profileDocument[@"avatarHash"];
        self.publicMessage = profileDocument[@"publicMessage"];
        self.displayName = profileDocument[@"displayName"];
        self.createdAt = [profileDocument[@"$createdAt"] unsignedLongValue];
        self.updatedAt = [profileDocument[@"$updatedAt"] unsignedLongValue];
        self.documentIdentifier = profileDocument[@"$id"];
    }
    return self;
}
- (instancetype)initWithDocument:(DDocument *)document {
    self = [super init];
    if (self) {
        DSLog(@"DSTransientDashpayUser: ");
        dash_spv_platform_document_print_document(document);
        switch (document->tag) {
            case dpp_document_Document_V0: {
//                break;
                dpp_document_v0_DocumentV0 *v0 = document->v0;
                self.revision = v0->revision ? (uint32_t) v0->revision->_0 : 0;
                self.createdAt = v0->created_at->_0;
                self.updatedAt = v0->updated_at->_0;
                self.documentIdentifier = NSDataFromPtr(v0->id->_0->_0);
                self.avatarPath = DGetTextDocProperty(document, @"avatarUrl");
//                v0 : id:EH766JkXC948sHdCovfMUJd1cmogZNtX5RsdzLibVEb9 owner_id:7im3W3XdyhQQ7tgaL8gwXV2HRD9UtipVRUR4KPgyWRMR
//                    created_at:2024-10-21 18:38:20
//                    updated_at:2025-01-28 06:53:28
//                    avatarFingerprint:bytes 5580290000410106
//                    avatarHash:bytes32 7bhfqnTVCmm7IVNhUpclZaBiGUgAdKakVgw+TigY+ac= avatarUrl:string https://i.imgur.com/[...(32)] displayName:string disp publicMessage:string ab
                self.avatarFingerprint = DGetBytesDocProperty(document, @"avatarFingerprint");
                self.avatarHash = DGetBytes32DocProperty(document, @"avatarHash");
                self.publicMessage = DGetTextDocProperty(document, @"publicMessage");
                self.displayName = DGetTextDocProperty(document, @"displayName");
                break;
            }
            default:
                break;
        }
    }
    return self;
}

@end
