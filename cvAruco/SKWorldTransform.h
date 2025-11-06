#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKWorldTransform : NSObject
@property(nonatomic) int arucoId;
@property(nonatomic) SCNMatrix4 transform;

@end

NS_ASSUME_NONNULL_END
