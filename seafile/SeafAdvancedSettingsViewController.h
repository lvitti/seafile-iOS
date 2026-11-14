#import <UIKit/UIKit.h>
@class SeafCustomHeaders;

/// A general home for advanced account settings. Headers are its first section.
@interface SeafAdvancedSettingsViewController : UITableViewController
- (instancetype)initWithHeaderStore:(SeafCustomHeaders *)store;
@end
