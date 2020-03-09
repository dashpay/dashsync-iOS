//
//  DSDocumentTransitionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSDocumentTransitionEntity+CoreDataProperties.h"

@implementation DSDocumentTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSDocumentTransitionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSDocumentTransitionEntity"];
}

@dynamic documents;
@dynamic contactProfileCreations;
@dynamic contactRequests;

@end
