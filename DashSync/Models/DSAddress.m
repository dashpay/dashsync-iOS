//
//  DSAddress.m
//  DashSync
//
//  Created by Sam Westrich on 6/3/18.
//

#import "DSAddress.h"
#import "DSDerivationPath.h"

@interface DSAddress()

@property(nonatomic,strong) DSDerivationPath * derivationPath;
@property(nonatomic,assign) BOOL internal;
@property(nonatomic,assign) uint32_t index;
@property(nonatomic,copy) NSString * addressString;

@end

@implementation DSAddress

//+(DSAddress*)addressWithAddressString:(NSString*)addressString onDerivationPath:(DSDerivationPath*)derivationPath atIndex:(uint32_t)index internal:(BOOL)internal {
//    
//}
//
//-(instancetype)initWithAddressString:(NSString*)addressString onDerivationPath:(DSDerivationPath*)derivationPath atIndex:(uint32_t)index internal:(BOOL)internal {
//    _addressString = addressString;
//    _derivationPath = derivationPath;
//    _index = index;
//    _internal = internal;
//}

@end
