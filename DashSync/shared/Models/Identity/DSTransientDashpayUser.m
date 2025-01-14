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
- (instancetype)initWithDocument:(dpp_document_Document *)document {
    self = [super init];
    if (self) {
        switch (document->tag) {
            case dpp_document_Document_V0: {
                dpp_document_v0_DocumentV0 *v0 = document->v0;
                self.revision = (uint32_t) v0->revision->_0;
                self.createdAt = v0->created_at->_0;
                self.updatedAt = v0->updated_at->_0;
                self.documentIdentifier = NSDataFromPtr(v0->id->_0->_0);
                platform_value_Value *avatar_path_value = dash_spv_platform_document_get_document_property(document, (char *)[@"avatarUrl" UTF8String]);
                platform_value_Value *avatar_fingerprint_value = dash_spv_platform_document_get_document_property(document, (char *)[@"avatarFingerprint" UTF8String]);
                platform_value_Value *avatar_hash_value = dash_spv_platform_document_get_document_property(document, (char *)[@"avatarHash" UTF8String]);
                platform_value_Value *public_message_value = dash_spv_platform_document_get_document_property(document, (char *)[@"publicMessage" UTF8String]);
                platform_value_Value *display_name_value = dash_spv_platform_document_get_document_property(document, (char *)[@"displayName" UTF8String]);
                self.avatarPath = [NSString stringWithCString:avatar_path_value->text encoding:NSUTF8StringEncoding];
                self.avatarFingerprint = NSDataFromPtr(avatar_fingerprint_value->identifier->_0);
                self.avatarHash = NSDataFromPtr(avatar_hash_value->identifier->_0);
                self.publicMessage = [NSString stringWithCString:public_message_value->text encoding:NSUTF8StringEncoding];
                self.displayName = [NSString stringWithCString:display_name_value->text encoding:NSUTF8StringEncoding];
                break;
            }
            default:
                break;
        }
    }
    return self;
}

@end
