//  SeafCollaboratorChipView.h
//  Reusable capsule view for collaborator display (avatar + name).
//  Used by both the profile sheet (via SeafCollaboratorChipCell) and the profile editor.

#import <UIKit/UIKit.h>

@class SeafConnection;

NS_ASSUME_NONNULL_BEGIN

@interface SeafCollaboratorChipView : UIView
@property (nonatomic, weak, nullable) SeafConnection *connection;
- (void)configureWithName:(NSString *)name avatarURL:(NSString * _Nullable)avatarURL;
@end

NS_ASSUME_NONNULL_END
