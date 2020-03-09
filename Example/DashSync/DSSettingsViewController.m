//
//  DSSettingsViewController.m
//  DashSync_Example
//
//  Created by Sam Westrich on 5/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import "DSSettingsViewController.h"

#import "DSOptionsManager.h"

#import "FormTableViewController.h"
#import "NumberTextFieldFormCellModel.h"
#import "SwitcherFormCellModel.h"

@interface DSSettingsViewController ()

@end

@implementation DSSettingsViewController

- (NSArray<BaseFormCellModel *> *)generalItems {
    NSMutableArray<BaseFormCellModel *> *items = [NSMutableArray array];

    DSOptionsManager *options = [DSOptionsManager sharedInstance];

    {
        SwitcherFormCellModel *cellModel = [[SwitcherFormCellModel alloc] initWithTitle:@"Keep Headers"];
        cellModel.on = options.keepHeaders;
        cellModel.didChangeValueBlock = ^(SwitcherFormCellModel *_Nonnull cellModel) {
            options.keepHeaders = cellModel.on;
        };
        [items addObject:cellModel];
    }

    {
        SwitcherFormCellModel *cellModel = [[SwitcherFormCellModel alloc] initWithTitle:@"Use MNL Checkpoints"];
        cellModel.on = options.useCheckpointMasternodeLists;
        cellModel.didChangeValueBlock = ^(SwitcherFormCellModel *_Nonnull cellModel) {
            options.useCheckpointMasternodeLists = cellModel.on;
        };
        [items addObject:cellModel];
    }

    {
        SwitcherFormCellModel *cellModel = [[SwitcherFormCellModel alloc] initWithTitle:@"Retrieve Price Info"];
        cellModel.on = options.retrievePriceInfo;
        cellModel.didChangeValueBlock = ^(SwitcherFormCellModel *_Nonnull cellModel) {
            options.retrievePriceInfo = cellModel.on;
        };
        [items addObject:cellModel];
    }


    SwitcherFormCellModel *genesisOptionCellModel = [[SwitcherFormCellModel alloc] initWithTitle:@"Sync from Genesis"];

    NumberTextFieldFormCellModel *syncHeightCellModel = [[NumberTextFieldFormCellModel alloc] initWithTitle:@"Sync from Height"
                                                                                                placeholder:@"Sync Height"];
    __weak SwitcherFormCellModel *weakGenesisOptionCellModel = genesisOptionCellModel;
    __weak NumberTextFieldFormCellModel *weakSyncHeightCellModel = syncHeightCellModel;

    genesisOptionCellModel.on = options.syncFromGenesis;
    genesisOptionCellModel.didChangeValueBlock = ^(SwitcherFormCellModel *_Nonnull cellModel) {
        options.syncFromGenesis = cellModel.on;

        __strong NumberTextFieldFormCellModel *strongSyncHeightCellModel = weakSyncHeightCellModel;
        strongSyncHeightCellModel.text = [NSString stringWithFormat:@"%u", options.syncFromHeight];
    };
    [items addObject:genesisOptionCellModel];

    syncHeightCellModel.text = [NSString stringWithFormat:@"%u", options.syncFromHeight];
    syncHeightCellModel.didChangeValueBlock = ^(TextFieldFormCellModel *_Nonnull cellModel) {
        options.syncFromHeight = (uint32_t)cellModel.text.longLongValue;

        __strong SwitcherFormCellModel *strongGenesisOptionCellModel = weakGenesisOptionCellModel;
        strongGenesisOptionCellModel.on = options.syncFromGenesis;
    };
    [items addObject:syncHeightCellModel];

    return items;
}

- (NSArray<BaseFormCellModel *> *)syncTypeItems {
    NSMutableArray<BaseFormCellModel *> *items = [NSMutableArray array];

    DSOptionsManager *options = [DSOptionsManager sharedInstance];

    NSDictionary<NSNumber *, NSString *> *syncTypes = @{
        @(DSSyncType_BaseSPV) : @"Base SPV",
        @(DSSyncType_FullBlocks) : @"Full Blocks",
        @(DSSyncType_Mempools) : @"Mempools",
        @(DSSyncType_MasternodeList) : @"Masternode List",
        @(DSSyncType_Governance) : @"Governance",
        @(DSSyncType_GovernanceVotes) : @"Governance Votes",
        @(DSSyncType_Sporks) : @"Sporks",
    };

    NSArray<NSNumber *> *sortedKeys = [syncTypes.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *key in sortedKeys) {
        DSSyncType syncType = key.unsignedIntegerValue;
        NSString *title = syncTypes[key];
        SwitcherFormCellModel *cellModel = [[SwitcherFormCellModel alloc] initWithTitle:title];
        cellModel.on = options.syncType & syncType;
        cellModel.didChangeValueBlock = ^(SwitcherFormCellModel *_Nonnull cellModel) {
            if (cellModel.on) {
                [options addSyncType:syncType];
            }
            else {
                [options clearSyncType:syncType];
            }
        };
        [items addObject:cellModel];
    }

    return items;
}

- (NSArray<FormSectionModel *> *)sections {
    NSMutableArray<FormSectionModel *> *sections = [NSMutableArray array];

    {
        FormSectionModel *section = [[FormSectionModel alloc] init];
        section.headerTitle = @"General";
        section.items = [self generalItems];
        [sections addObject:section];
    }

    {
        FormSectionModel *section = [[FormSectionModel alloc] init];
        section.headerTitle = @"Sync Types";
        section.items = [self syncTypeItems];
        [sections addObject:section];
    }

    return sections;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    FormTableViewController *formController = [[FormTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    formController.sections = [self sections];

    [self addChildViewController:formController];
    formController.view.frame = self.view.bounds;
    formController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:formController.view];
    [formController didMoveToParentViewController:self];
}

@end
