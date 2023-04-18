//
//  DSChainsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSChainsViewController.h"
#import "DSAddDevnetViewController.h"
#import "DSChainTableViewCell.h"
#import "DSSyncViewController.h"
#import <DashSync/DashSync.h>

@interface DSChainsViewController ()

@property (strong, nonatomic) id addChainsObserver;

@end

@implementation DSChainsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self destroyDevnets];
//    This extracts ip addresses of masternodes from dash-network-configs and wraps into objc string format
    
//    grep "masternode-" malort.txt | grep -oE 'public_ip=((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | sed "s/ /\" \"/g;s/^/@\"/;s/$/\",/"
//    [self setup333];
//    [self setupMalort];
//    [self setupKrupnik];
//    [self setupOuzo];
//    [self setupMekhong];
//    [self setupJackDaniels];
//    [self setupChacha];
    [self setupWhiteRussian];
    [self.tableView reloadData];

    self.addChainsObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainsDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          NSLog(@"Added/removed a chain");
                                                          [self.tableView reloadData];
                                                      }];
}

- (void)destroyDevnets {
    NSArray *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    for (DSChain *chain in devnetChains) {
        [[DSChainsManager sharedInstance] removeDevnetChain:chain];
    }
}

- (void)setupChacha {
    [self setupDevnetWithId:DevnetType_Chacha
               sporkAddress:@"ybiRzdGWFeijAgR7a8TJafeNi6Yk6h68ps"
            sporkPrivateKey:@"cPTms6Sd7QuhPWXWQSzMbvg2VbEPsWCsLBbR4PBgvfYRzAPazbt3"
         minProtocolVersion:70225
            protocolVersion:70225
    minimumDifficultyBlocks:1000000
                  addresses:@[
        @"34.213.73.187",
        @"35.166.223.113",
        @"34.222.70.155",
        @"54.188.28.123",
        @"52.33.126.127",
        @"34.212.132.210",
        @"54.191.175.225",
        @"54.213.218.58",
        @"34.210.252.158",
        @"34.221.203.109",
        @"52.38.9.28",
        @"34.221.123.183",
        @"35.91.217.175",
        @"34.211.90.216",
        @"35.89.101.137",
        @"52.40.174.175",
        @"34.221.153.236",
        @"54.189.17.85",
    ] walletPhrase:nil];

}


- (void)setup333 {
    [self setupDevnetWithId:DevnetType_Devnet333
               sporkAddress:@"yM6zJAMWoouAZxPvqGDbuHb6BJaD6k4raQ"
            sporkPrivateKey:@"cQnP9JNQp6oaZrvBtqBWRMeQERMkDyuXyvQh1qaph4FdP6cT2cVa"
         minProtocolVersion:70221
            protocolVersion:70221
    minimumDifficultyBlocks:1000000
                  addresses:@[
        @"34.220.100.153",
        @"52.12.210.34",
        @"54.71.255.176",
        @"54.187.123.197",
        @"34.217.195.49",
        @"35.89.69.137",
        @"34.210.15.156",
        @"52.39.39.40",
        @"54.245.132.133",
        @"18.236.89.14",
        @"35.163.60.183",
        @"18.237.244.153",
    ] walletPhrase:nil];
}


- (void)setupJackDaniels {
    [self setupDevnetWithId:DevnetType_JackDaniels
               sporkAddress:@"yYBanbwp2Pp2kYWqDkjvckY3MosuZzkKp7"
            sporkPrivateKey:@"cTeGz53m7kHgA9L75s4vqFGR89FjYz4D9o44eHfoKjJr2ArbEtwg"
         minProtocolVersion:70219
            protocolVersion:70220
    minimumDifficultyBlocks:4032
                  addresses:@[
        @"34.220.200.8",
        @"35.90.255.217",
        @"54.218.109.249",
        @"35.91.227.162",
        @"34.222.40.218",
        @"35.88.38.193",
        @"35.91.226.251",
        @"35.160.157.3",
        @"18.237.219.248",
        @"35.91.210.71",
        @"35.89.227.73",
        @"35.90.188.155",
        @"35.91.132.97",
        @"52.26.218.0",
        @"18.236.242.154",
        @"35.87.198.41",
        @"34.220.65.60",
        @"35.90.106.60",
        @"54.200.34.46",
        @"34.221.71.106",
        @"52.40.10.67",
        @"54.245.163.29",
        @"34.222.54.201",
        @"34.211.49.161",
        @"34.222.47.179",
        @"35.91.139.106",
        @"35.89.107.148",
        @"54.202.58.56",
        @"54.212.110.64",
        @"35.89.25.223",
        @"35.91.168.239",
        @"34.219.242.157",
        @"54.245.137.49",
        @"34.222.42.179",
        @"34.220.158.197",
        @"54.70.92.75",
    ] walletPhrase:nil];
}

- (void)setupMojito {
    [self setupDevnetWithId:DevnetType_Mojito
                   sporkAddress:@"yXePLfsnJHGbM2LAWcxXaJaixX4qKs38g1"
                sporkPrivateKey:@"cS4ikCxcqorwKuGNxMfpX8paBqSjnQsqMuM8YjLvSZZd6gcp7WQg"
             minProtocolVersion:70225
                protocolVersion:70225
        minimumDifficultyBlocks:4032
                      addresses:@[
        @"35.91.72.103",
        @"35.87.140.64",
        @"35.88.93.189",
        @"54.212.13.99",
        @"52.32.240.193",
        @"54.71.209.203",
        @"34.220.229.64",
        @"54.185.157.224",
        @"34.219.83.228",
        @"52.42.97.123",
        @"35.89.120.122",
        @"18.237.57.30",
        @"54.149.185.48",
        @"35.163.184.206",
        @"35.89.100.95",
        @"35.88.254.18",
        @"34.220.68.151",
        @"35.162.144.29",
    ]
               walletPhrase:nil];
}

- (void)setupWhiteRussian {
    [self setupDevnetWithId:DevnetType_WhiteRussian
                   sporkAddress:@"yZaEFuVfaycMzvQbHH7dgbDPJ6F2AGLqzR"
                sporkPrivateKey:@"cTvYmnZxCK7A8HekGQYMD7yuXSxVKnwgVVo7fHQrcbzckxYm2g7M"
             minProtocolVersion:70227
                protocolVersion:70227
        minimumDifficultyBlocks:4032
                      addresses:@[
        @"35.85.152.110",
        @"34.209.13.56",
        @"52.42.93.34",
        @"35.87.154.139",
        @"35.92.216.172",
        @"34.222.169.49",
        @"52.27.159.100",
        @"35.90.131.248",
        @"34.211.144.169",
        @"35.163.17.85",
        @"52.26.67.115",
        @"35.92.6.130",
        @"54.191.109.168",
        @"52.39.100.224",
        @"54.200.39.51",
        @"54.185.210.60",
        @"35.89.197.145",
        @"18.246.65.63",
    ]
               walletPhrase:nil];

}

- (void)setupDevnetWithId:(DevnetType)devnetType
             sporkAddress:(NSString *)sporkAddress
          sporkPrivateKey:(NSString *)sporkPrivateKey
       minProtocolVersion:(uint32_t)minProtocolVersion
          protocolVersion:(uint32_t)protocolVersion
  minimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
                addresses:(NSArray<NSString *> *)addresses
             walletPhrase:(NSString *_Nullable)walletPhrase {
//    NSString *chainID = [NSString stringWithFormat:@"devnet-%@", identifier];
    NSMutableOrderedSet<NSString *> *insertedIPAddresses = [NSMutableOrderedSet orderedSetWithArray:addresses];
    NSArray<DSChain *> *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    DSChain *chain = nil;
    for (DSChain *devnetChain in devnetChains) {
        if (devnet_type_for_chain_type(devnetChain.chainType) == devnetType) {
            chain = devnetChain;
            break;
        }
    }
    uint32_t dashdPort = 20001;
    uint32_t dapiJRPCPort = DEVNET_DAPI_JRPC_STANDARD_PORT;
    uint32_t dapiGRPCPort = DEVNET_DAPI_GRPC_STANDARD_PORT;
        
    UInt256 dpnsContractID = UINT256_ZERO;
    UInt256 dashpayContractID = UINT256_ZERO;
//    uint32_t version = 1;

    if (chain) {
        [[DSChainsManager sharedInstance] updateDevnetChain:chain
                                        forServiceLocations:insertedIPAddresses
                                    minimumDifficultyBlocks:minimumDifficultyBlocks
                                               standardPort:dashdPort
                                               dapiJRPCPort:dapiJRPCPort
                                               dapiGRPCPort:dapiGRPCPort
                                             dpnsContractID:dpnsContractID
                                          dashpayContractID:dashpayContractID
                                            protocolVersion:protocolVersion
                                         minProtocolVersion:minProtocolVersion
                                               sporkAddress:sporkAddress
                                            sporkPrivateKey:sporkPrivateKey];
    } else {
        chain = [[DSChainsManager sharedInstance] registerDevnetChainWithIdentifier:devnetType
                                                                forServiceLocations:insertedIPAddresses
                                                        withMinimumDifficultyBlocks:minimumDifficultyBlocks
                                                                       standardPort:dashdPort
                                                                       dapiJRPCPort:dapiJRPCPort
                                                                       dapiGRPCPort:dapiGRPCPort
                                                                     dpnsContractID:dpnsContractID
                                                                  dashpayContractID:dashpayContractID
                                                                    protocolVersion:protocolVersion
                                                                 minProtocolVersion:minProtocolVersion
                                                                       sporkAddress:sporkAddress
                                                                    sporkPrivateKey:sporkPrivateKey];
    }
    if (walletPhrase) {
        DSWallet *wallet = [DSWallet standardWalletWithSeedPhrase:walletPhrase setCreationDate:0 forChain:chain storeSeedPhrase:YES isTransient:NO];
        [chain registerWallet:wallet];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2 + [[[DSChainsManager sharedInstance] devnetChains] count];
}

- (DSChain *)chainForIndex:(NSInteger)index {
    if (index == 0) return [DSChain mainnet];
    if (index == 1) return [DSChain testnet];
    NSInteger devnetIndex = index - 2;
    NSArray *devnetChains = [[DSChainsManager sharedInstance] devnetChains];
    return [devnetChains objectAtIndex:devnetIndex];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DSChainTableViewCell *cell = (DSChainTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"chainTableViewCell" forIndexPath:indexPath];
    DSChain *chain = [self chainForIndex:indexPath.row];
    if (cell) {
        cell.chainNameLabel.text = chain.name;
    }

    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row > 1;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"Delete"
                                                                             handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView, void (^_Nonnull completionHandler)(BOOL)) {
                                                                                 DSChain *chain = [self chainForIndex:indexPath.row];
                                                                                 [[DSChainsManager sharedInstance] removeDevnetChain:chain];
                                                                             }];
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:@"Edit"
                                                                           handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView, void (^_Nonnull completionHandler)(BOOL)) {
                                                                               [self performSegueWithIdentifier:@"AddDevnetSegue" sender:[self.tableView cellForRowAtIndexPath:indexPath]];
                                                                           }];
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
    config.performsFirstActionWithFullSwipe = false;
    return config;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    UITableViewCell *cell = (UITableViewCell *)sender;
    NSInteger index = [self.tableView indexPathForCell:cell].row;
    if ([segue.identifier isEqualToString:@"ChainDetailsSegue"]) {
        DSSyncViewController *syncViewController = (DSSyncViewController *)segue.destinationViewController;
        DSChain *chain = [self chainForIndex:index];
        [[DSVersionManager sharedInstance] upgradeExtendedKeysForWallets:chain.wallets
                                                             withMessage:@"Upgrade keys"
                                                          withCompletion:^(BOOL success, BOOL neededUpgrade, BOOL authenticated, BOOL cancelled){

                                                          }];
        syncViewController.chainManager = [[DSChainsManager sharedInstance] chainManagerForChain:chain];
        syncViewController.title = chain.name;
    } else if ([segue.identifier isEqualToString:@"AddDevnetSegue"]) {
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            DSAddDevnetViewController *addDevnetViewController = (DSAddDevnetViewController *)((UINavigationController *)segue.destinationViewController).topViewController;
            DSChain *chain = [self chainForIndex:index];
            addDevnetViewController.chain = chain;
        }
    }
}


@end
