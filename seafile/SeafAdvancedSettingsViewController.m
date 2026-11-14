#import "SeafAdvancedSettingsViewController.h"
#import "SeafCustomHeaders.h"

@interface SeafHeaderEditor : UITableViewController
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, copy) NSDictionary *header;
@property (nonatomic, copy) BOOL (^saveHeader)(NSDictionary *, NSError **);
@end

static void ShowHeaderError(UIViewController *controller, NSError *error) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Custom headers", nil)
        message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

@implementation SeafHeaderEditor
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.header ? NSLocalizedString(@"Edit header", nil) : NSLocalizedString(@"Add header", nil);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];
    self.nameField = [self fieldWithLabel:NSLocalizedString(@"Header name", nil)];
    self.valueField = [self fieldWithLabel:NSLocalizedString(@"Header value", nil)];
    self.valueField.secureTextEntry = YES;
    self.nameField.text = self.header[@"name"];
    self.valueField.text = self.header[@"value"];
    self.valueField.accessibilityLabel = NSLocalizedString(@"Header value", nil);
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
}
- (UITextField *)fieldWithLabel:(NSString *)label {
    UITextField *field = [UITextField new];
    field.placeholder = label;
    field.accessibilityLabel = label;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.spellCheckingType = UITextSpellCheckingTypeNo;
    field.smartQuotesType = UITextSmartQuotesTypeNo;
    field.smartDashesType = UITextSmartDashesTypeNo;
    field.keyboardType = UIKeyboardTypeASCIICapable;
    field.textContentType = @"";
    field.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    field.adjustsFontForContentSizeCategory = YES;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    return field;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 3; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.row == 2) {
        cell.textLabel.text = NSLocalizedString(@"Show value", nil);
        UISwitch *toggle = [UISwitch new];
        [toggle addTarget:self action:@selector(showValue:) forControlEvents:UIControlEventValueChanged];
        toggle.accessibilityLabel = cell.textLabel.text;
        cell.accessoryView = toggle;
    } else {
        UITextField *field = indexPath.row == 0 ? self.nameField : self.valueField;
        field.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:field];
        [NSLayoutConstraint activateConstraints:@[
            [field.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [field.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [field.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [field.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
            [field.heightAnchor constraintGreaterThanOrEqualToConstant:24]]];
    }
    return cell;
}
- (void)showValue:(UISwitch *)toggle { self.valueField.secureTextEntry = !toggle.on; }
- (void)cancel { self.valueField.text = @""; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)save {
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSDictionary *header = @{ @"name": name ?: @"", @"value": self.valueField.text ?: @"" };
    NSError *error = nil;
    if (self.saveHeader(header, &error)) [self cancel];
    else ShowHeaderError(self, error);
}
@end

@interface SeafAdvancedSettingsViewController ()
@property (nonatomic, strong) SeafCustomHeaders *store;
@property (nonatomic, copy) NSDictionary *profile;
@end

@implementation SeafAdvancedSettingsViewController
- (instancetype)initWithHeaderStore:(SeafCustomHeaders *)store {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.store = store;
        self.title = NSLocalizedString(@"Advanced", nil);
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadProfile)];
    [self reloadProfile];
}
- (void)reloadProfile {
    NSError *error = nil;
    self.profile = [self.store load:&error];
    [self.tableView reloadData];
    if (error) dispatch_async(dispatch_get_main_queue(), ^{ ShowHeaderError(self, error); });
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.profile ? 2 : 0; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : [self.profile[@"headers"] count] + 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? NSLocalizedString(@"Custom HTTP headers", nil) : nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return NSLocalizedString(@"Disabling headers keeps their saved values. You can still edit or delete them.", nil);
    NSURL *URL = [NSURL URLWithString:self.store.server];
    NSString *origin = [NSString stringWithFormat:@"%@://%@%@", URL.scheme ?: @"", URL.host ?: @"", URL.port ? [NSString stringWithFormat:@":%@", URL.port] : @""];
    NSString *scope = [NSString stringWithFormat:NSLocalizedString(@"Only sent to %@ for this account. Values are saved in this device's Keychain.", nil), origin];
    if (![self.profile[@"headers"] count]) scope = [NSLocalizedString(@"No headers configured.", nil) stringByAppendingFormat:@"\n%@", scope];
    return scope;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0;
    if (indexPath.section == 0) {
        cell.textLabel.text = NSLocalizedString(@"Send custom headers", nil);
        UISwitch *toggle = [UISwitch new];
        toggle.on = [self.profile[@"enabled"] boolValue];
        toggle.accessibilityLabel = cell.textLabel.text;
        [toggle addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.row == [self.profile[@"headers"] count]) {
        cell.textLabel.text = NSLocalizedString(@"Add header", nil);
        cell.textLabel.textColor = self.view.tintColor;
        cell.imageView.image = [UIImage systemImageNamed:@"plus"];
    } else {
        cell.textLabel.text = self.profile[@"headers"][indexPath.row][@"name"];
        cell.detailTextLabel.text = @"••••••••";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessibilityHint = NSLocalizedString(@"Edit header. Swipe left for Delete.", nil);
    }
    return cell;
}
- (BOOL)persist:(NSArray *)headers enabled:(BOOL)enabled error:(NSError **)error {
    if (![self.store saveHeaders:headers enabled:enabled error:error]) return NO;
    self.profile = @{ @"headers": [headers copy], @"enabled": @(enabled) };
    return YES;
}
- (void)enabledChanged:(UISwitch *)toggle {
    NSError *error = nil;
    if (![self persist:self.profile[@"headers"] enabled:toggle.on error:&error]) {
        toggle.on = [self.profile[@"enabled"] boolValue];
        ShowHeaderError(self, error);
    }
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;
    BOOL adding = indexPath.row == [self.profile[@"headers"] count];
    SeafHeaderEditor *editor = [[SeafHeaderEditor alloc] initWithStyle:UITableViewStyleInsetGrouped];
    editor.header = adding ? nil : self.profile[@"headers"][indexPath.row];
    __weak typeof(self) weakSelf = self;
    editor.saveHeader = ^BOOL(NSDictionary *header, NSError **error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return NO;
        NSMutableArray *headers = [self.profile[@"headers"] mutableCopy];
        if (adding) [headers addObject:header]; else headers[indexPath.row] = header;
        // First manually-added header opts in. Subsequent edits preserve the switch.
        BOOL enabled = headers.count == 1 && adding ? YES : [self.profile[@"enabled"] boolValue];
        if (![self persist:headers enabled:enabled error:error]) return NO;
        [self.tableView reloadData];
        return YES;
    };
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:editor] animated:YES completion:nil];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1 || indexPath.row >= [self.profile[@"headers"] count]) return nil;
    __weak typeof(self) weakSelf = self;
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:NSLocalizedString(@"Delete", nil) handler:^(UIContextualAction *action, UIView *sourceView, void (^completion)(BOOL)) {
        // Retract the native swipe action before presenting its confirmation.
        completion(NO);
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSDictionary *header = self.profile[@"headers"][indexPath.row];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete header?", nil)
            message:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ and its saved value? This cannot be undone.", nil), header[@"name"]]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            NSMutableArray *headers = [self.profile[@"headers"] mutableCopy];
            [headers removeObjectAtIndex:indexPath.row];
            NSError *error = nil;
            if (![self persist:headers enabled:[self.profile[@"enabled"] boolValue] error:&error]) {
                dispatch_async(dispatch_get_main_queue(), ^{ ShowHeaderError(self, error); });
                return;
            }
            [self.tableView performBatchUpdates:^{
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } completion:^(BOOL finished) { [self.tableView reloadData]; }];
        }]];
        dispatch_async(dispatch_get_main_queue(), ^{ [self presentViewController:alert animated:YES completion:nil]; });
    }];
    action.image = [UIImage systemImageNamed:@"trash"];
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[action]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}
@end
