//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSErrorSimulationsViewController.h"

#import "DSErrorSimulationManager.h"

#import "FormTableViewController.h"
#import "NumberTextFieldFormCellModel.h"
#import "SwitcherFormCellModel.h"


@interface DSErrorSimulationsViewController ()

@end

@implementation DSErrorSimulationsViewController

- (NSArray<BaseFormCellModel *> *)generalItems {
    NSMutableArray<BaseFormCellModel *> *items = [NSMutableArray array];

    DSErrorSimulationManager *options = [DSErrorSimulationManager sharedInstance];

    {
        SwitcherFormCellModel *cellModel = [[SwitcherFormCellModel alloc] initWithTitle:@"Enabled"];
        cellModel.on = options.enabled;
        cellModel.didChangeValueBlock = ^(SwitcherFormCellModel *_Nonnull cellModel) {
            options.enabled = cellModel.on;
        };
        [items addObject:cellModel];
    }

    return items;
}

- (NSArray<BaseFormCellModel *> *)l1Items {
    NSMutableArray<BaseFormCellModel *> *items = [NSMutableArray array];

    DSErrorSimulationManager *options = [DSErrorSimulationManager sharedInstance];

    NumberTextFieldFormCellModel *l1DisconnectionFrequencyCellModel = [[NumberTextFieldFormCellModel alloc] initWithTitle:@"Disconnection Frequency"
                                                                                                              placeholder:@"Frequency"];

    l1DisconnectionFrequencyCellModel.text = [NSString stringWithFormat:@"%u", options.peerRandomDisconnectionFrequency];
    l1DisconnectionFrequencyCellModel.didReturnValueBlock = ^(TextFieldFormCellModel *_Nonnull cellModel) {
        options.peerRandomDisconnectionFrequency = (uint32_t)cellModel.text.longLongValue;
    };
    [items addObject:l1DisconnectionFrequencyCellModel];

    NumberTextFieldFormCellModel *l1ByzantineOmissionCellModel = [[NumberTextFieldFormCellModel alloc] initWithTitle:@"Byzantine Omission Frequency"
                                                                                                         placeholder:@"Frequency"];

    l1ByzantineOmissionCellModel.text = [NSString stringWithFormat:@"%u", options.peerByzantineTransactionOmissionFrequency];
    l1ByzantineOmissionCellModel.didReturnValueBlock = ^(TextFieldFormCellModel *_Nonnull cellModel) {
        options.peerByzantineTransactionOmissionFrequency = (uint32_t)cellModel.text.longLongValue;
    };
    [items addObject:l1ByzantineOmissionCellModel];

    NumberTextFieldFormCellModel *l1ByzantineReportingHigherEstimatedBlockHeightFrequencyCellModel = [[NumberTextFieldFormCellModel alloc] initWithTitle:@"Higher Est. Block Height Frequency"
                                                                                                                                             placeholder:@"Frequency"];

    l1ByzantineReportingHigherEstimatedBlockHeightFrequencyCellModel.text = [NSString stringWithFormat:@"%u", options.peerByzantineReportingHigherEstimatedBlockHeightFrequency];
    l1ByzantineReportingHigherEstimatedBlockHeightFrequencyCellModel.didReturnValueBlock = ^(TextFieldFormCellModel *_Nonnull cellModel) {
        options.peerByzantineReportingHigherEstimatedBlockHeightFrequency = (uint32_t)cellModel.text.longLongValue;
    };
    [items addObject:l1ByzantineReportingHigherEstimatedBlockHeightFrequencyCellModel];

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
        section.headerTitle = @"Peer Network (Using percentage frequencies)";
        section.items = [self l1Items];
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
