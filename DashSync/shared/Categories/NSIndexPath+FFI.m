//  
//  Created by Vladimir Pirogov
//  Copyright © 2023 Dash Core Group. All rights reserved.
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

#import "NSIndexPath+FFI.h"

@implementation NSIndexPath (FFI)

- (IndexPathData *)ffi_malloc {
    IndexPathData *obj = malloc(sizeof(IndexPathData));
    NSUInteger *indexes = calloc(self.length, sizeof(NSUInteger));
    [self getIndexes:indexes];
    obj->indexes = indexes;
    obj->len = self.length;
    
    
//    NSUInteger length = indexPath.length;
//    NSUInteger *indexes = calloc(length, sizeof(NSUInteger));
//    [indexPath getIndexes:indexes];
//    IndexPathData index_path = {.indexes = indexes, .len = length };

    return obj;
}

+ (void)ffi_free:(IndexPathData *)entry {
    if (entry->len > 0) {
        free((void *) entry->indexes);
    }
    free(entry);
}

@end
