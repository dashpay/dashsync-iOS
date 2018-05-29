//
//  DSWalletViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 4/20/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSWalletViewController.h"
#import "NSManagedObject+Sugar.h"
#import "DSWalletTableViewCell.h"
#import <DashSync/DashSync.h>
#import "DSWalletInputPhraseViewController.h"

@interface DSWalletViewController ()

@property (nonatomic,strong) id<NSObject> chainObserver;

@end

@implementation DSWalletViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.chainObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletAddedNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self.tableView reloadData];
                                                       }];
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//Put this back in when we have multi wallet feature

//- (NSFetchedResultsController *)fetchedResultsController {
//
//    if (_fetchedResultsController != nil) {
//        return _fetchedResultsController;
//    }
//    NSManagedObjectContext * context = [NSManagedObject context];
//    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
//    NSEntityDescription *entity = [NSEntityDescription
//                                   entityForName:@"DSWalletEntity" inManagedObjectContext:context];
//    [fetchRequest setEntity:entity];
//
//    NSSortDescriptor *sort = [[NSSortDescriptor alloc]
//                              initWithKey:@"created" ascending:NO];
//    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
//
//    [fetchRequest setFetchBatchSize:20];
//
//    NSFetchedResultsController *theFetchedResultsController =
//    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
//                                        managedObjectContext:context sectionNameKeyPath:nil
//                                                   cacheName:nil];
//    self.fetchedResultsController = theFetchedResultsController;
//    _fetchedResultsController.delegate = self;
//
//    return _fetchedResultsController;
//
//}
//
//- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
//    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
//    [self.tableView beginUpdates];
//}
//
//
//- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
//
//    UITableView *tableView = self.tableView;
//
//    switch(type) {
//
//        case NSFetchedResultsChangeInsert:
//            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
//            break;
//
//        case NSFetchedResultsChangeDelete:
//            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
//            break;
//
//        case NSFetchedResultsChangeUpdate:
//            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
//            break;
//
//        case NSFetchedResultsChangeMove:
//            [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
//            break;
//    }
//}
//
//
//- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
//    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
//    [self.tableView endUpdates];
//}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.chain.wallets count];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"WalletCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Set up the cell...
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

-(void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    @autoreleasepool {
        DSWalletTableViewCell * walletCell = (DSWalletTableViewCell*)cell;
        DSWallet * wallet = [[self.chain wallets] objectAtIndex:indexPath.row];
        NSString * passphrase = [wallet seedPhraseIfAuthenticated];
        NSArray * components = [passphrase componentsSeparatedByString:@" "];
        NSMutableArray * lines = [NSMutableArray array];
        for (int i = 0;i<[components count];i+=4) {
            [lines addObject:[[components subarrayWithRange:NSMakeRange(i, 4)] componentsJoinedByString:@" "]];
        }
        
        walletCell.passphraseLabel.text = [lines componentsJoinedByString:@"\n"];
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120;
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return TRUE;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AddWalletSegue"]) {
        DSWalletInputPhraseViewController * walletInputViewController = (DSWalletInputPhraseViewController*)segue.destinationViewController;
        walletInputViewController.chain = self.chain;
    }
}

@end
