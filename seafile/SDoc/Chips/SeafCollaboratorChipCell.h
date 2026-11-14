//  SeafCollaboratorChipCell.h

#import <UIKit/UIKit.h>

@class SeafConnection;

NS_ASSUME_NONNULL_BEGIN

@interface SeafCollaboratorChipCell : UICollectionViewCell
@property (nonatomic, weak, nullable) SeafConnection *connection;
- (void)configureWithName:(NSString *)name avatarURL:(NSString * _Nullable)avatarURL;
@end

NS_ASSUME_NONNULL_END

