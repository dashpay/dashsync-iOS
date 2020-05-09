//  
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/// Eliminates boilerplate code around NSFetchedResultsController
@interface DSFetchedResultsTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (readonly, nonatomic, strong) NSManagedObjectContext *context;
@property (readonly, nonatomic, copy) NSString *entityName;
@property (readonly, nonatomic, strong) NSPredicate *predicate;
@property (readonly, nonatomic, strong) NSPredicate *invertedPredicate;
@property (readonly, nonatomic, copy) NSArray<NSSortDescriptor *> *sortDescriptors;

@property (null_resettable, nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
