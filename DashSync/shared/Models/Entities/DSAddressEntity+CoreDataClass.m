//
//  DSAddressEntity+CoreDataClass.m
//
//
//  Created by Sam Westrich on 5/20/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSAddressEntity

- (uint64_t)balance {
    uint64_t b = 0;
    for (DSTxOutputEntity *output in self.usedInOutputs) {
        if (!output.spentInInput) b += output.value;
    }
    return b;
}

- (uint64_t)inAmount {
    uint64_t b = 0;
    for (DSTxOutputEntity *output in self.usedInOutputs) {
        b += output.value;
    }
    return b;
}

- (uint64_t)outAmount {
    uint64_t b = 0;
    for (DSTxOutputEntity *output in self.usedInOutputs) {
        if (output.spentInInput) b += output.value;
    }
    return b;
}

+ (DSAddressEntity *)addressMatching:(NSString *)address onChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context {
    NSArray<DSAddressEntity *> *addressEntities = [DSAddressEntity objectsInContext:context matching:@"address == %@ && derivationPath.chain == %@", address, [chain chainEntityInContext:context]];
    if ([addressEntities count]) {
        NSAssert([addressEntities count] == 1, @"addresses should not be duplicates");
        return [addressEntities firstObject];
    } else {
        DSAddressEntity *addressEntity = [DSAddressEntity managedObjectInBlockedContext:context];
        addressEntity.address = address;
        addressEntity.index = UINT32_MAX;
        return addressEntity;
    }
}

+ (DSAddressEntity *)findAddressMatching:(NSString *)address onChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context {
#if (0 && DEBUG) //this is for testing
    NSArray<DSAddressEntity *> *addressEntities = [DSAddressEntity objectsInContext:context matching:@"address == %@ && derivationPath.chain == %@", address, [chain chainEntityInContext:context]];
    if ([addressEntities count]) {
        NSAssert([addressEntities count] == 1, @"addresses should not be duplicates");
        return [addressEntities firstObject];
    }
    return nil;
#else
    return [DSAddressEntity anyObjectInContext:context matching:@"address == %@ && derivationPath.chain == %@", address, [chain chainEntityInContext:context]];
#endif
}

+ (NSArray<DSAddressEntity *> *)findAddressesIn:(NSSet<NSString *> *)addresses onChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context {
    return [DSAddressEntity objectsInContext:context matching:@"address IN %@ && derivationPath.chain == %@", addresses, [chain chainEntityInContext:context]];
}

+ (NSDictionary<NSString *, DSAddressEntity *> *)findAddressesAndIndexIn:(NSSet<NSString *> *)addresses onChain:(DSChain *)chain inContext:(NSManagedObjectContext *)context {
    NSArray *addressEntities = [self findAddressesIn:addresses onChain:chain inContext:context];
    NSMutableArray *addressStringsOfEntities = [NSMutableArray array];
    for (DSAddressEntity *addressEntity in addressEntities) {
        [addressStringsOfEntities addObject:addressEntity.address];
    }
    return [NSDictionary dictionaryWithObjects:addressEntities forKeys:addressStringsOfEntities]; //!OCLINT
}

+ (void)deleteAddressesOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *addressesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(derivationPath.chain == %@)", chainEntity];
        for (DSAddressEntity *address in addressesToDelete) {
            [chainEntity.managedObjectContext deleteObject:address];
        }
    }];
}

@end
