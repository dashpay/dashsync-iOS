//
//  DSSporkEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class DSSpork;

@interface DSSporkEntity : NSManagedObject

- (void)setAttributesFromSpork:(DSSpork *)spork;

@end

NS_ASSUME_NONNULL_END

#import "DSSporkEntity+CoreDataProperties.h"
