//
//  DSSimpleIndexedDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSDerivationPath+Protected.h"
#import "DSSimpleIndexedDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSSimpleIndexedDerivationPath ()

@property (nonatomic, strong) NSMutableArray *mOrderedAddresses;

//- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
