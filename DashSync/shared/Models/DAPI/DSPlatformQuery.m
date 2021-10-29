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

#import "DSPlatformQuery.h"
#import "DPDocument.h"
#import "DSDocumentType.h"
#import "DSPlatformDocumentsRequest.h"
#import "DSPlatformPathQuery.h"
#import "DSPlatformTreeQuery.h"

@interface DSPlatformQuery ()

@property (nonatomic, strong) NSDictionary<NSNumber *, DSPlatformTreeQuery *> *treeQueries;

@end

@implementation DSPlatformQuery

+ (DSPlatformQuery *)platformQueryForIdentityID:(NSData *)identityID {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformTreeQuery *identitiesQuery = [DSPlatformTreeQuery platformTreeQueryForKeys:@[identityID]];
    query.treeQueries = @{@(DSPlatformDictionary_Identities): identitiesQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForContractID:(NSData *)contractID {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformTreeQuery *contractsQuery = [DSPlatformTreeQuery platformTreeQueryForKeys:@[contractID]];
    query.treeQueries = @{@(DSPlatformDictionary_Contracts): contractsQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForIndividualDocumentKeys:(NSArray<NSData *> *)documentKeys inPath:(NSArray<NSData *> *)path {
    //todo improve when we have secondary indexes
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformTreeQuery *documentKeysQuery = [DSPlatformTreeQuery platformTreeQueryForKeys:documentKeys];
    query.treeQueries = @{@(DSPlatformDictionary_Documents): documentKeysQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForGetIdentityIDsByPublicKeyHashes:(NSArray<NSData *> *)publicKeyHashes {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformTreeQuery *identitiesPublicKeyHashesQuery = [DSPlatformTreeQuery platformTreeQueryForKeys:publicKeyHashes];
    query.treeQueries = @{@(DSPlatformDictionary_PublicKeyHashesToIdentityIds): identitiesPublicKeyHashesQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForGetIdentitiesByPublicKeyHashes:(NSArray<NSData *> *)publicKeyHashes {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformTreeQuery *identitiesPublicKeyHashesQuery = [DSPlatformTreeQuery platformTreeQueryForKeys:publicKeyHashes];
    query.treeQueries = @{@(DSPlatformDictionary_PublicKeyHashesToIdentityIds): identitiesPublicKeyHashesQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForGetContractsByContractIDs:(NSArray<NSData *> *)contractIDs {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformTreeQuery *contractsQuery = [DSPlatformTreeQuery platformTreeQueryForKeys:contractIDs];
    query.treeQueries = @{@(DSPlatformDictionary_Contracts): contractsQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForDocuments:(NSArray<DPDocument *> *)documents {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    // We should group all documents of the same type
    NSMutableDictionary<NSData *, NSMutableArray<NSData *> *> *keysByTypePath = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSData *, NSArray<NSData *> *> *pathsByTypePath = [NSMutableDictionary dictionary];
    for (DPDocument *document in documents) {
        NSData *serializedPath = document.documentType.serializedPath;
        if (![keysByTypePath objectForKey:serializedPath]) {
            keysByTypePath[serializedPath] = [NSMutableArray array];
            pathsByTypePath[serializedPath] = document.documentType.path;
        }
        [keysByTypePath[serializedPath] addObject:document.mainIndexKey];
    }
    NSMutableArray *queryPaths = [NSMutableArray array];
    for (NSData *documentType in keysByTypePath) {
        NSArray<NSData *> *path = pathsByTypePath[documentType];
        NSArray<NSData *> *keys = keysByTypePath[documentType];
        DSPlatformPathQuery *pathQuery = [DSPlatformPathQuery platformPath:path queryForKeys:keys];
        [queryPaths addObject:pathQuery];
    }
    DSPlatformTreeQuery *documentKeysQuery = [DSPlatformTreeQuery platformTreeQueryForPaths:queryPaths];
    query.treeQueries = @{@(DSPlatformDictionary_Documents): documentKeysQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryDocumentTreeQuery:(DSPlatformTreeQuery *)documentTreeQuery {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    query.treeQueries = @{@(DSPlatformDictionary_Documents): documentTreeQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForKeys:(NSArray<NSData *> *)keys inPath:(NSArray<NSData *> *)path {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformPathQuery *pathQuery = [DSPlatformPathQuery platformPath:path queryForKeys:keys];
    DSPlatformTreeQuery *documentKeysQuery = [DSPlatformTreeQuery platformTreeQueryForPaths:@[pathQuery]];
    query.treeQueries = @{@(DSPlatformDictionary_Documents): documentKeysQuery};
    return query;
}

+ (DSPlatformQuery *)platformQueryForRanges:(NSArray<DSDirectionalRange *> *)ranges inPath:(NSArray<NSData *> *)path {
    DSPlatformQuery *query = [[DSPlatformQuery alloc] init];
    DSPlatformPathQuery *pathQuery = [DSPlatformPathQuery platformPath:path queryForRanges:ranges];
    DSPlatformTreeQuery *documentKeysQuery = [DSPlatformTreeQuery platformTreeQueryForPaths:@[pathQuery]];
    query.treeQueries = @{@(DSPlatformDictionary_Documents): documentKeysQuery};
    return query;
}


- (DSPlatformTreeQuery *)treeQueryForType:(DSPlatformDictionary)treeType {
    return [self.treeQueries objectForKey:@(treeType)];
}


@end
