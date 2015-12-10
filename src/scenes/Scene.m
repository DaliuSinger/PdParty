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
#include "Scene.h"

@implementation Scene

+ (id)sceneWithParent:(UIView *)parent {
	Scene *s = [[Scene alloc] init];
	s.parentView = parent;
	return s;
}

- (id)init {
    self = [super init];
    if(self) {
		self.preferredOrientations = UIInterfaceOrientationMaskAll;
	}
    return self;
}

- (void)dealloc {
	[self close];
}

- (BOOL)open:(NSString *)path {
	return YES;
}

- (void)close {
	self.parentView = nil;
	self.gui = nil;
}

- (void)reshape {
}

// normalize to whole view
- (BOOL)scaleTouch:(UITouch *)touch forPos:(CGPoint *)pos {
	return NO;
}

#pragma mark Overridden Getters / Setters

- (NSString *)name {
	return @"EmptyScene";
}


- (BOOL)hasInfo {
	return NO;
}

- (NSString *)artist {
	return @"Unknown Artist";
}

- (NSString *)category {
	return @"None";
}

- (NSString *)description {
	return @"None";
}

- (SceneType)type {
	return SceneTypeEmpty;
}

- (NSString *)typeString {
	return @"EmptyScene";
}

- (int)sampleRate {
	return PARTY_SAMPLERATE;
}

- (BOOL)requiresAccel {
	return NO;
}

- (BOOL)requiresTouch {
	return NO;
}

- (BOOL)supportsLocate {
	return NO;
}

- (BOOL)supportsHeading {
	return NO;
}

- (BOOL)requiresKeys {
	return NO;
}

- (BOOL)requiresOnscreenControls {
	return NO;
}

- (int)contentHeight {
	return CGRectGetHeight(self.parentView.bounds);
}

#pragma mark Util

- (void)addSearchPathsIn:(NSString *)directory {
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
		DDLogWarn(@"%@: search path %@ not found, skipping", self.typeString, directory);
		return;
	}
	DDLogVerbose(@"%@: adding search paths in %@", self.typeString, directory);

	NSError *error;
	NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:&error];
	if(!contents) {
		DDLogError(@"%@: couldn't read contents of path %@, error: %@", self.typeString, directory, error.localizedDescription);
		return;
	}
	
	DDLogVerbose(@"%@: found %lu paths", self.typeString, contents.count);
	for(NSString *p in contents) {
		NSString *path = [directory stringByAppendingPathComponent:p];
		if([Util isDirectory:path]) {
			DDLogVerbose(@"%@: \tadded %@ to search path", self.typeString, p);
			[PdBase addToSearchPath:path];
		}
	}
}

+ (UIInterfaceOrientationMask)orientationMaskFromWidth:(float)width andHeight:(float)height {
	float aspect = width / height;
	if(aspect < 1.0) { // portrait
		return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
	}
	else if(aspect > 1.0) { // landscape
		return UIInterfaceOrientationMaskLandscape;
	}
	return UIInterfaceOrientationMaskAll;
}

@end
