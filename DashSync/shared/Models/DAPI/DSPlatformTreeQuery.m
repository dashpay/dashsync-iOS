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

@interface DSPlatformTreeQuery()

@property(nonatomic, strong) NSArray<NSData*> * platformQueryKeys;
@property(nonatomic, strong) NSArray<NSArray<NSData*>*> * platformQueryKeyRanges;
@property(nonatomic, assign) Keys * keys;

@end

@implementation DSPlatformTreeQuery

+(DSPlatformTreeQuery*)platformTreeQueryForKeys:(NSArray<NSData*>*)keys{
    return [[self alloc] initWithKeys:keys andRanges:nil];
}

+(DSPlatformTreeQuery*)platformTreeQueryForRanges:(NSArray<NSArray<NSData*>*>*)keyRanges {
    return [[self alloc] initWithKeys:nil andRanges:keyRanges];
}

+(DSPlatformTreeQuery*)platformTreeQueryForKeys:(NSArray<NSData*>*)keys andRanges:(NSArray<NSArray<NSData*>*>*)keyRanges {
    return [[self alloc] initWithKeys:keys andRanges:keyRanges];
}

-(instancetype)initWithKeys:(NSArray<NSData*>*)keys andRanges:(NSArray<NSArray<NSData*>*>*)keyRanges {
    self = [super init];
    if (self) {
        self.platformQueryKeys = keys;
        self.platformQueryKeyRanges = keyRanges;
        [self createMerkKeys];
    }
    return self;
}

-(void)createMerkKeys {
    Keys * k = malloc(sizeof(Keys));
    k->element_count = self.platformQueryKeys.count + self.platformQueryKeyRanges.count;
    k->elements = malloc(k->element_count*sizeof(Query *));
    int i = 0;
    for (NSData * data in self.platformQueryKeys) {
        Query * query = malloc(sizeof(Query));
        query->key_length = data.length;
        query->key = malloc(data.length);
        query->key_end_length = 0;
        memcpy(query->key, data.bytes, data.length);
        k->elements[i*sizeof(Query *)] = query;
        i++;
    }
    for (NSArray <NSData*>* range in self.platformQueryKeyRanges) {
        NSData * startKey = range.firstObject;
        NSData * endKey = range.lastObject;
        Query * query = malloc(sizeof(Query));
        query->key_length = startKey.length;
        query->key = malloc(startKey.length);
        memcpy(query->key, startKey.bytes, startKey.length);
        query->key_end_length = endKey.length;
        query->key_end = malloc(endKey.length);
        memcpy(query->key_end, endKey.bytes, endKey.length);
        k->elements[i*sizeof(Query *)] = query;
        i++;
    }
    self.keys = k;
}

-(void)destroyMerkKeys {
    Keys *k = self.keys;
    for (int i = 0; i < k->element_count; i++) {
        Query *q = k->elements[i*sizeof(Query *)];
        free(q->key);
        if (q->key_end_length) {
            free(q->key_end);
        }
        free(q);
    }
    free(k->elements);
    free(k);
}

-(void)dealloc {
    [self destroyMerkKeys];
}

@end
