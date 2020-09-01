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

#import "DSCoreDataMigrationStep.h"

#import "NSManagedObjectModel+DS.h"
#import "DSTransaction.h"

@implementation DSCoreDataMigrationStep

- (instancetype)initWithSourceVersion:(DSCoreDataMigrationVersionValue)sourceVersion
                   destinationVersion:(DSCoreDataMigrationVersionValue)destinationVersion {
    self = [super init];
    if (self) {
        _sourceModel = [NSManagedObjectModel ds_managedObjectModelForResource:[DSCoreDataMigrationVersion modelResourceForVersion:sourceVersion]];
        _destinationModel = [NSManagedObjectModel ds_managedObjectModelForResource:[DSCoreDataMigrationVersion modelResourceForVersion:destinationVersion]];
        _mappingModel = [self.class mappingModelFromSourceModel:_sourceModel toDestinationModel:_destinationModel];
        NSAssert(_mappingModel != nil, @"Expected modal mapping not present");
    }
    return self;
}

+ (nullable NSMappingModel *)mappingModelFromSourceModel:(NSManagedObjectModel *)sourceModel
                                      toDestinationModel:(NSManagedObjectModel *)destinationModel {
    NSMappingModel *custom = [self customMappingModelFromSourceModel:sourceModel toDestinationModel:destinationModel];
    if (custom != nil) {
        return custom;
    }
    
    return [self inferredMappingModelFromSourceModel:sourceModel toDestinationModel:destinationModel];
}

+ (nullable NSMappingModel *)inferredMappingModelFromSourceModel:(NSManagedObjectModel *)sourceModel
                                              toDestinationModel:(NSManagedObjectModel *)destinationModel {
    return [NSMappingModel inferredMappingModelForSourceModel:sourceModel destinationModel:destinationModel error:nil];
}

+ (nullable NSMappingModel *)customMappingModelFromSourceModel:(NSManagedObjectModel *)sourceModel
                                            toDestinationModel:(NSManagedObjectModel *)destinationModel {
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[DSTransaction class]];
    NSURL *bundleURL = [[frameworkBundle resourceURL] URLByAppendingPathComponent:@"DashSync.bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithURL:bundleURL];
    NSParameterAssert(resourceBundle);
    return [NSMappingModel mappingModelFromBundles:@[resourceBundle]
                                    forSourceModel:sourceModel
                                  destinationModel:destinationModel];
}

@end
