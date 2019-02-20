//
//  DSSimpleIndexedDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSSimpleIndexedDerivationPath : DSDerivationPath

- (NSUInteger)indexOfAddress:(NSString*)address;

@end

NS_ASSUME_NONNULL_END
