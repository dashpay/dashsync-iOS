//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "FormTableViewController.h"

#import "SelectorFormTableViewCell.h"
#import "SwitcherFormTableViewCell.h"
#import "TextFieldFormTableViewCell.h"
#import "TextViewFormTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SELECTOR_CELL_ID = @"SelectorFormTableViewCell";
static NSString *const TEXTFIELD_CELL_ID = @"TextFieldFormTableViewCell";
static NSString *const SWITCHER_CELL_ID = @"SwitcherFormTableViewCell";
static NSString *const TEXTVIEW_CELL_ID = @"TextViewFormTableViewCell";

@interface FormTableViewController () <TextFieldFormTableViewCellDelegate>
@end

@implementation FormTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    NSArray<NSString *> *cellIds = @[
        SELECTOR_CELL_ID,
        TEXTFIELD_CELL_ID,
        SWITCHER_CELL_ID,
        TEXTVIEW_CELL_ID,
    ];
    for (NSString *cellId in cellIds) {
        UINib *nib = [UINib nibWithNibName:cellId bundle:nil];
        NSParameterAssert(nib);
        [self.tableView registerNib:nib forCellReuseIdentifier:cellId];
    }
}

- (void)setSections:(nullable NSArray<FormSectionModel *> *)sections {
    _sections = [sections copy];
    
    [self.tableView reloadData];
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    FormSectionModel *sectionModel = self.sections[section];
    return sectionModel.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FormSectionModel *sectionModel = self.sections[indexPath.section];
    NSArray<BaseFormCellModel *> *items = sectionModel.items;
    BaseFormCellModel *cellModel = items[indexPath.row];

    if ([cellModel isKindOfClass:SelectorFormCellModel.class]) {
        SelectorFormTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SELECTOR_CELL_ID forIndexPath:indexPath];
        cell.cellModel = (SelectorFormCellModel *)cellModel;
        return cell;
    }
    else if ([cellModel isKindOfClass:TextViewFormCellModel.class]) {
        TextViewFormTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TEXTVIEW_CELL_ID forIndexPath:indexPath];
        cell.cellModel = (TextViewFormCellModel *)cellModel;
        return cell;
    }
    else if ([cellModel isKindOfClass:TextFieldFormCellModel.class]) {
        TextFieldFormTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TEXTFIELD_CELL_ID forIndexPath:indexPath];
        cell.cellModel = (TextFieldFormCellModel *)cellModel;
        cell.delegate = self;
        return cell;
    }
    else if ([cellModel isKindOfClass:SwitcherFormCellModel.class]) {
        SwitcherFormTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SWITCHER_CELL_ID forIndexPath:indexPath];
        cell.cellModel = (SwitcherFormCellModel *)cellModel;
        return cell;
    }
    else {
        NSAssert(NO, @"Unknown cell model %@", cellModel);

        return [UITableViewCell new];
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    FormSectionModel *sectionModel = self.sections[section];
    return sectionModel.headerTitle;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    FormSectionModel *sectionModel = self.sections[section];
    return sectionModel.footerTitle;
}

#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.view endEditing:YES];

    FormSectionModel *sectionModel = self.sections[indexPath.section];
    NSArray<BaseFormCellModel *> *items = sectionModel.items;
    BaseFormCellModel *cellModel = items[indexPath.row];

    if ([cellModel isKindOfClass:SelectorFormCellModel.class]) {
        [self showValueSelectorForDetail:(SelectorFormCellModel *)cellModel];
    }
    else if ([cellModel isKindOfClass:SwitcherFormCellModel.class]) {
        SwitcherFormCellModel *switcherModel = (SwitcherFormCellModel *)cellModel;
        switcherModel.on = !switcherModel.on;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    FormSectionModel *sectionModel = self.sections[indexPath.section];
    NSArray<BaseFormCellModel *> *items = sectionModel.items;
    BaseFormCellModel *cellModel = items[indexPath.row];
    return cellModel.cellHeight;
}

#pragma mark TextFieldFormTableViewCellDelegate

- (void)textFieldFormTableViewCellActivateNextFirstResponder:(TextFieldFormTableViewCell *)cell {
    TextFieldFormCellModel *cellModel = cell.cellModel;
    NSParameterAssert((cellModel.returnKeyType == UIReturnKeyNext));
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath) {
        return;
    }
    
    for (NSUInteger i = indexPath.section; i < self.sections.count; i++) {
        FormSectionModel *sectionModel = self.sections[i];
        NSUInteger j = (indexPath.section == i) ? indexPath.row + 1 : 0;
        for (; j < sectionModel.items.count; j++) {
            TextFieldFormCellModel *cellModel = (TextFieldFormCellModel *)sectionModel.items[j];
            if ([cellModel isKindOfClass:TextFieldFormCellModel.class]) {
                NSIndexPath *nextIndexPath = [NSIndexPath indexPathForRow:j inSection:i];
                id<TextInputFormTableViewCell> cell = [self.tableView cellForRowAtIndexPath:nextIndexPath];
                if ([cell conformsToProtocol:@protocol(TextInputFormTableViewCell)]) {
                    [cell textInputBecomeFirstResponder];
                }
                else {
                    NSAssert(NO, @"Invalid cell class for TextFieldFormCellModel");
                }
                
                return; // we're done
            }
        }
    }
}

#pragma mark Private

- (void)showValueSelectorForDetail:(SelectorFormCellModel *)cellModel {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:cellModel.title
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    for (id<NamedObject> value in cellModel.values) {
        [alertController addAction:[UIAlertAction actionWithTitle:value.name
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *_Nonnull action) {
                                                              cellModel.selectedValue = value;
                                                              if (cellModel.didChangeValueBlock) {
                                                                  cellModel.didChangeValueBlock(cellModel);
                                                              }
                                                          }]];
    }
    [self presentViewController:alertController animated:YES completion:nil];
}

@end

NS_ASSUME_NONNULL_END
