//
//  Created by Sam Westrich
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSPlatformTreeQuery.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSPlatformDictionary)
{
    DSPlatformDictionary_Contracts = 3,
    DSPlatformDictionary_Documents = 4,
    DSPlatformDictionary_Identities = 1,
    DSPlatformDictionary_PublicKeyHashesToIdentityIds = 2,
};

@class DPDocument, DSDirectionalRange;

@interface DSPlatformQuery : NSObject

@property (nonatomic, readonly) NSDictionary<NSNumber *, DSPlatformTreeQuery *> *treeQueries;

+ (DSPlatformQuery *)platformQueryForIdentityID:(NSData *)identityID;
+ (DSPlatformQuery *)platformQueryForContractID:(NSData *)contractID;
+ (DSPlatformQuery *)platformQueryForGetContractsByContractIDs:(NSArray<NSData *> *)contractIDs;
+ (DSPlatformQuery *)platformQueryForIndividualDocumentKeys:(NSArray<NSData *> *)documentKeys inPath:(NSArray<NSData *> *)path;
+ (DSPlatformQuery *)platformQueryForDocuments:(NSArray<DPDocument *> *)documents;
+ (DSPlatformQuery *)platformQueryDocumentTreeQuery:(DSPlatformTreeQuery *)documentTreeQuery;
+ (DSPlatformQuery *)platformQueryForKeys:(NSArray<NSData *> *)keys inPath:(NSArray<NSData *> *)path;
+ (DSPlatformQuery *)platformQueryForRanges:(NSArray<DSDirectionalRange *> *)ranges inPath:(NSArray<NSData *> *)path;
+ (DSPlatformQuery *)platformQueryForGetIdentityIDsByPublicKeyHashes:(NSArray<NSData *> *)publicKeyHashes;
+ (DSPlatformQuery *)platformQueryForGetIdentitiesByPublicKeyHashes:(NSArray<NSData *> *)publicKeyHashes;

- (DSPlatformTreeQuery *)treeQueryForType:(DSPlatformDictionary)treeType;

@end

NS_ASSUME_NONNULL_END
