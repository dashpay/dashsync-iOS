//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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
#import "dash_shared_core.h"
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

#define DArcProcessor std_sync_Arc_dash_spv_masternode_processor_processing_processor_MasternodeProcessor
#define DArcCache std_sync_Arc_dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache
#define DArcPlatformSDK std_sync_Arc_dash_spv_platform_PlatformSDK
#define DArcIdentitiesManager std_sync_Arc_dash_spv_platform_identity_manager_IdentitiesManager
#define DArcContractsManager std_sync_Arc_dash_spv_platform_contract_manager_ContractsManager
#define DArcDocumentsManager std_sync_Arc_dash_spv_platform_document_manager_DocumentsManager
#define DArcContactRequestManager std_sync_Arc_dash_spv_platform_document_contact_request_ContactRequestManager
#define DSaltedDomainHashesManager std_sync_Arc_dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashesManager

@class DSChain;

@interface DSDashSharedCore : NSObject

- (instancetype)initOnChain:(DSChain *)chain;

- (DArcProcessor *)processor;
- (DArcCache *)cache;
- (DArcPlatformSDK *)platform;
- (Runtime *)runtime;
- (DArcIdentitiesManager *)identitiesManager;
- (DArcContractsManager *)contractsManager;
- (DArcDocumentsManager *)documentsManager;
- (DArcContactRequestManager *)contactRequests;
- (DSaltedDomainHashesManager *)saltedDomainHashes;

@property (nonatomic, readonly) BOOL hasMasternodeListCurrentlyBeingSaved;

@end

NS_ASSUME_NONNULL_END
