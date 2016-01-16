/*
 * Copyright (c) 2013 Dan Wilcox <danomatika@gmail.com>
 *
 * BSD Simplified License.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 * See https://github.com/danomatika/PdParty for documentation
 *
 */
#import <UIKit/UIKit.h>

#import "AllScenes.h"
#import "Sensors.h"
#import "PureData.h"
#import "Osc.h"

@interface SceneManager : NSObject

@property (strong, nonatomic) Gui *gui; // pd gui widgets
@property (strong, nonatomic) Scene* scene; // current scene
@property (strong, readonly, nonatomic) NSString* currentPath; // the current given path

@property (strong, nonatomic) Sensors *sensors; //< internal sensor manager
@property (weak, nonatomic) PureData *pureData;
@property (weak, nonatomic) Osc *osc;

@property (assign, nonatomic) UIInterfaceOrientation currentOrientation; // accel orientation based on this

// close the current scene and open a new one, requires full path to current patch
- (BOOL)openScene:(NSString *)path withType:(SceneType)type forParent:(UIView *)parent;

// reload the current scene
- (BOOL)reloadScene;

// close the current scene
- (void)closeScene;

// reshape the gui elements to a give size
- (void)reshapeToParentSize:(CGSize)size;

// update view pointers in case the patch view controller has changed  
- (void)updateParent:(UIView *)parent;

#pragma mark Send Events

// rj touch event
- (void)sendTouch:(NSString *)eventType forId:(int)id atX:(float)x andY:(float)y;

// pd key event
- (void)sendKey:(int)key;

@end