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
 #import "SceneManager.h"

#import <CoreMotion/CoreMotion.h>
#import "Log.h"
#import "Gui.h"
#import "AppDelegate.h"

// androidy update speed defines
#define SENSOR_UI_HZ      10.0
#define SENSOR_NORMAL_HZ  30.0
#define SENSOR_GAME_HZ    60.0
#define SENSOR_FASTEST_HZ 100.0

@interface SceneManager () {
	
	CMMotionManager *motionManager; // for accel data
	
	CLLocationManager *locationManager; // for location data
	BOOL hasIgnoredStartingLocation; // ignore the initial, old location
	NSDateFormatter *locationDateFormatter, *headingDateFormatter;
	
	BOOL hasReshaped; // has the gui been reshaped?
}
@property (strong, readwrite, nonatomic) NSString* currentPath;
@property (assign, readwrite, getter=isRecording, nonatomic) BOOL recording;
@end

@implementation SceneManager

- (id)init {
	self = [super init];
	if(self) {
		
		hasReshaped = NO;
		
		// init motion manager
		motionManager = [[CMMotionManager alloc] init];
		
		// current UI orientation for accel
		if([Util isDeviceATablet]) { // iPad can started rotated
			self.currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];
		}
		else { // do not start rotated on iPhone
			self.currentOrientation = UIInterfaceOrientationPortrait;
		}
		
		// init location manager
		locationManager = [[CLLocationManager alloc] init];
		locationManager.delegate = self;
		
		// set osc and pure data pointer
		AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		self.osc = app.osc;
		self.pureData = app.pureData;
		
		// create gui
		self.gui = [[Gui alloc] init];
	}
		
	return self;
}

- (void)dealloc {
	if(self.pureData) {
		self.pureData.sensorDelegate = nil;
	}
}

- (BOOL)openScene:(NSString *)path withType:(SceneType)type forParent:(UIView *)parent {
	return [self openScene:path withType:type forParent:parent allowReload:NO];
}

// helper
- (BOOL)openScene:(NSString *)path withType:(SceneType)type forParent:(UIView *)parent allowReload:(BOOL)reload {
	if(!reload && [self.currentPath isEqualToString:path]) {
		DDLogVerbose(@"SceneManager openScene: ignoring scene with same path");
		return NO;
	}
	
	// close open scene
	[self closeScene];
	
	// open new scene
	switch(type) {
		case SceneTypePatch:
			self.scene = [PatchScene sceneWithParent:parent andGui:self.gui];
			break;
		case SceneTypeRj:
			self.scene = [RjScene sceneWithParent:parent andDispatcher:self.pureData.dispatcher];
			break;
		case SceneTypeDroid:
			self.scene = [DroidScene sceneWithParent:parent andGui:self.gui];
			break;
		case SceneTypeParty:
			self.scene = [PartyScene sceneWithParent:parent andGui:self.gui];
			break;
		case SceneTypeRecording:
			self.scene = [RecordingScene sceneWithParent:parent andPureData:self.pureData];
			break;
		default: // SceneTypeEmpty
			self.scene = [[Scene alloc] init];
			break;
	}
	self.pureData.audioEnabled = YES;
	self.pureData.sampleRate = self.scene.sampleRate;
	self.enableAccel = self.scene.requiresAccel;
	self.pureData.playing = YES;
	[self.scene open:path];
	
	// turn up volume & turn on transport, update gui
	[self.pureData sendCurrentPlayValues];
	
	// store current location
	self.currentPath = path;
	
	return YES;
}

- (BOOL)reloadScene {
	if(!self.scene) {
		DDLogVerbose(@"SceneManager reloadScene: ignoring empty scene reload");
		return NO;
	}
	DDLogVerbose(@"SceneManager: reloading %@", self.scene.name);
	SceneType type = self.scene.type;
	UIView *parent = self.scene.parentView;
	[self closeScene];
	return [self openScene:self.currentPath withType:type forParent:parent allowReload:YES];
}

- (void)closeScene {
	if(self.scene) {
		if(self.pureData.isRecording) {
			[self.pureData stopRecording];
		}
		[PureData sendCloseBang];
		[self.scene close];
		self.scene = nil;
		self.enableAccel = NO;
		self.enableMagnet = NO;
		self.enableGyro = NO;
		self.enableLocation = NO;
		self.enableHeading = NO;
		hasReshaped = NO;
	}
}

- (void)reshapeToParentSize:(CGSize)size {
	
	self.gui.parentViewSize = size;
	
	if(!self.scene) {
		return;
	}
		
	// do animations if gui has already been setup once
	// http://www.techotopia.com/index.php/Basic_iOS_4_iPhone_Animation_using_Core_Animation
	if(hasReshaped) {
		[UIView beginAnimations:nil context:nil];
	}
	[self.scene reshape];
	if(hasReshaped) {
		[UIView commitAnimations];
	}
	else {
		hasReshaped = YES;
	}
}

- (void)updateParent:(UIView *)parent {
	if(!self.scene) {
		return;
	}
	self.scene.parentView = parent;
}

#pragma mark Send Events

- (void)sendTouch:(NSString *)eventType forId:(int)id atX:(float)x andY:(float)y {
	if(self.scene.requiresTouch) {
		[PureData sendTouch:eventType forId:id atX:x andY:y];
	}
	if(self.osc.isListening) {
		[self.osc sendTouch:eventType forId:id atX:x andY:y];
	}
}

// pd key event
- (void)sendKey:(int)key {
	if(self.scene.requiresKeys) {
		[PureData sendKey:key];
	}
	if(self.osc.isListening) {
		[self.osc sendKey:key];
	}
}

#pragma mark Overridden Getters / Setters

- (void)setPureData:(PureData *)pureData {
	if(_pureData) {
		_pureData.sensorDelegate = nil;
	}
	_pureData = pureData;
	_pureData.sensorDelegate = self;
}

- (void)setCurrentOrientation:(UIInterfaceOrientation)currentOrientation {
	_currentOrientation = currentOrientation;
	// TODO: currently dosen't handle faceup / facedown UIDeviceOrientations
	locationManager.headingOrientation = currentOrientation;
}

- (void)setEnableAccel:(BOOL)enableAccel {
	if(self.enableAccel == enableAccel) {
		return;
	}
	_enableAccel = enableAccel;
	
	// start
	if(enableAccel) {
		if([motionManager isAccelerometerAvailable]) {
			NSTimeInterval interval = 1.0/SENSOR_NORMAL_HZ;
			[motionManager setAccelerometerUpdateInterval:interval];
			
			// accel data callback block
			[motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue]
				withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
//					DDLogVerbose(@"accel %f %f %f", accelerometerData.acceleration.x,
//													accelerometerData.acceleration.y,
//													accelerometerData.acceleration.z);
					// orient accel data to current orientation
					switch(self.currentOrientation) {
						case UIInterfaceOrientationPortrait:
							[PureData sendAccel:accelerometerData.acceleration.x
											  y:accelerometerData.acceleration.y
											  z:accelerometerData.acceleration.z];
							[self.osc sendAccel:accelerometerData.acceleration.x
											  y:accelerometerData.acceleration.y
											  z:accelerometerData.acceleration.z];
							break;
						case UIInterfaceOrientationLandscapeRight:
							[PureData sendAccel:-accelerometerData.acceleration.y
											  y:accelerometerData.acceleration.x
											  z:accelerometerData.acceleration.z];
							[self.osc sendAccel:-accelerometerData.acceleration.y
											  y:accelerometerData.acceleration.x
											  z:accelerometerData.acceleration.z];
							break;
						case UIInterfaceOrientationPortraitUpsideDown:
							[PureData sendAccel:-accelerometerData.acceleration.x
											  y:-accelerometerData.acceleration.y
											  z:accelerometerData.acceleration.z];
							[self.osc sendAccel:-accelerometerData.acceleration.x
											  y:-accelerometerData.acceleration.y
											  z:accelerometerData.acceleration.z];
							break;
						case UIInterfaceOrientationLandscapeLeft:
							[PureData sendAccel:accelerometerData.acceleration.y
											  y:-accelerometerData.acceleration.x
											  z:accelerometerData.acceleration.z];
							[self.osc sendAccel:accelerometerData.acceleration.y
											  y:-accelerometerData.acceleration.x
											  z:accelerometerData.acceleration.z];
							break;
						case UIInterfaceOrientationUnknown:
							break;
					}
				}];
			DDLogVerbose(@"SceneManager: accel enabled");
		}
		else {
			DDLogWarn(@"SceneManager: accel not available on this device");
		}
	}
	else { // stop
		if([motionManager isAccelerometerActive]) {
			[motionManager stopAccelerometerUpdates];
			DDLogVerbose(@"SceneManager: accel disabled");
		}
	}
}

- (void)setEnableGyro:(BOOL)enableGyro {
	if(self.enableGyro == enableGyro) {
		return;
	}
	_enableGyro = enableGyro;
	
	NSString *msg;
	
	// start
	if(enableGyro) {
		if([motionManager isGyroAvailable]) {
			[motionManager setGyroUpdateInterval:1.0/SENSOR_NORMAL_HZ];
			
			// gyro data callback block
			[motionManager startGyroUpdatesToQueue:[NSOperationQueue mainQueue]
				withHandler:^(CMGyroData *data, NSError *error) {
//				DDLogVerbose(@"gyro %f %f %f", data.rotationRate.x, data.rotationRate.y, data.rotationRate.z);
				[PureData sendGyro:data.rotationRate.x y:data.rotationRate.y z:data.rotationRate.z];
				[self.osc sendGyro:data.rotationRate.x y:data.rotationRate.y z:data.rotationRate.z];
			}];
			DDLogVerbose(@"SceneManager: gyro enabled");
		}
		else {
			DDLogWarn(@"SceneManager: gyro not available on this device");
		}
	}
	else { // stop
		if([motionManager isGyroActive]) {
			[motionManager stopGyroUpdates];
			DDLogVerbose(@"SceneManager: gyro disabled");
		}
	}
}

- (void)setEnableMagnet:(BOOL)enableMagnet {
	if(self.enableMagnet == enableMagnet) {
		return;
	}
	_enableMagnet = enableMagnet;
	
	NSString *msg;
	
	// start
	if(enableMagnet) {
		if([motionManager isMagnetometerAvailable]) {
			[motionManager setMagnetometerUpdateInterval:1.0/SENSOR_NORMAL_HZ];
			
			// gyro data callback block
			[motionManager startMagnetometerUpdatesToQueue:[NSOperationQueue mainQueue]
				withHandler:^(CMMagnetometerData *data, NSError *error) {
//				DDLogVerbose(@"magnet %f %f %f", data.magneticField.x, data.magneticField.y, data.magneticField.z);
				[PureData sendMagnet:data.magneticField.x y:data.magneticField.y z:data.magneticField.z];
				[self.osc sendMagnet:data.magneticField.x y:data.magneticField.y z:data.magneticField.z];
			}];
			DDLogVerbose(@"SceneManager: magnetometer enabled");
		}
		else {
			DDLogWarn(@"SceneManager: magnetometer not available on this device");
		}
	}
	else { // stop
		if([motionManager isMagnetometerActive]) {
			[motionManager stopMagnetometerUpdates];
			DDLogVerbose(@"SceneManager: magnetometer disabled");
		}
	}
}

- (void)setEnableLocation:(BOOL)enableLocation {
	if(self.enableLocation == enableLocation) {
		return;
	}
	_enableLocation = enableLocation;
	
	NSString *msg;
	
	// start
	if(enableLocation) {
		if([CLLocationManager locationServicesEnabled]) {
			
			hasIgnoredStartingLocation = NO;
			
			locationDateFormatter = [[NSDateFormatter alloc] init];
			[locationDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
			
			locationManager.desiredAccuracy = kCLLocationAccuracyBest;
			locationManager.distanceFilter = kCLDistanceFilterNone;
			[locationManager startUpdatingLocation];
			[self.pureData sendPrint:@"locate enabled"];
		}
		else {
			[self.pureData sendPrint:@"location services disabled or not available on this device"];
		}
	}
	else { // stop
		if([CLLocationManager locationServicesEnabled]) {
			[locationManager stopUpdatingLocation];
			locationDateFormatter = nil;
			[self.pureData sendPrint:@"locate disabled"];
		}
	}
}

- (void)setEnableHeading:(BOOL)enableHeading {
	if(self.enableHeading == enableHeading) {
		return;
	}
	_enableHeading = enableHeading;
	
	NSString *msg;
	
	// start
	if(enableHeading) {
		if([CLLocationManager headingAvailable]) {
			
			headingDateFormatter = [[NSDateFormatter alloc] init];
			[headingDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
			
			locationManager.headingFilter = 1;
			[locationManager startUpdatingHeading];
			[self.pureData sendPrint:@"heading enabled"];
		}
		else {
			[self.pureData sendPrint:@"heading not available on this device"];
		}
	}
	else { // stop
		if([CLLocationManager headingAvailable]) {
			[locationManager stopUpdatingHeading];
			headingDateFormatter = nil;
			[self.pureData sendPrint:@"heading disabled"];
		}
	}
}

#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	
	NSString *statusString;
	switch(status) {
		
		case kCLAuthorizationStatusRestricted:
			statusString = @"restricted";
			if([CLLocationManager locationServicesEnabled]) {
				[locationManager stopUpdatingLocation];
			}
			break;
   
		case kCLAuthorizationStatusDenied:
			if([CLLocationManager locationServicesEnabled]) {
				[locationManager stopUpdatingLocation];
			}
			statusString = @"denied";
			break;
		
		case kCLAuthorizationStatusAuthorized:
			statusString = @"authorized";
			break;
		
		default:
			statusString = @"not determined";
			break;
	}
	DDLogVerbose(@"SceneManager: location authorization: %@", statusString);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {

	// ignore stale stored location when starting
	if(!hasIgnoredStartingLocation) {
		CLLocation *location = [locations objectAtIndex:0];
		if(fabs([location.timestamp timeIntervalSinceNow]) > 1.0) {
			hasIgnoredStartingLocation = YES;
			return; // assume there aren't any extra locations in the array
		}
	}
	
	// handle locations, oldest is first
	for(CLLocation *location in locations) {
		
//		DDLogVerbose(@"locate %@", location.description);
		
		NSString *timestamp = [locationDateFormatter stringFromDate:location.timestamp];
		
		[PureData sendLocate:location.coordinate.latitude
						 lon:location.coordinate.longitude
						 alt:location.altitude
					   speed:location.speed
					   course:location.course
				horzAccuracy:location.horizontalAccuracy
				vertAccuracy:location.verticalAccuracy
				   timestamp:timestamp];
		
		[self.osc sendLocate:location.coordinate.latitude
						 lon:location.coordinate.longitude
						 alt:location.altitude
					   speed:location.speed
					   course:location.course
				horzAccuracy:location.horizontalAccuracy
				vertAccuracy:location.verticalAccuracy
				   timestamp:timestamp];
	}
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager {
	DDLogVerbose(@"SceneManager: location updates paused");
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
	DDLogVerbose(@"SceneManager: location updates resumed");
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {

//	DDLogVerbose(@"heading %@", newHeading.description);
	
	NSString *timestamp = [headingDateFormatter stringFromDate:newHeading.timestamp];
	
	[PureData sendHeading:newHeading.magneticHeading
				 accuracy:newHeading.headingAccuracy
				timestamp:timestamp];
				
	[self.osc sendHeading:newHeading.magneticHeading
				 accuracy:newHeading.headingAccuracy
				timestamp:timestamp];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	DDLogError(@"SceneManager: location manager error: %@", error.localizedDescription);
}

#pragma mark PdLocationEventDelegate

- (void)startAccelUpdates {
	if(self.scene.supportsAccel) {
		self.enableAccel = YES;
	}
}

- (void)stopAccelUpdates {
	if(self.scene.supportsAccel) {
		self.enableAccel = NO;
	}
}

- (void)setAccelSpeed:(NSString *)speed {

	if([speed isEqualToString:@"slow"]) {
		[motionManager setAccelerometerUpdateInterval:1.0/SENSOR_UI_HZ];
	}
	else if([speed isEqualToString:@"normal"]) {
		[motionManager setAccelerometerUpdateInterval:1.0/SENSOR_NORMAL_HZ];
	}
	else if([speed isEqualToString:@"fast"]) {
		[motionManager setAccelerometerUpdateInterval:1.0/SENSOR_GAME_HZ];
	}
	else if([speed isEqualToString:@"fastest"]) {
		[motionManager setAccelerometerUpdateInterval:1.0/SENSOR_FASTEST_HZ];
	}
	else {
		[self.pureData sendPrint:[NSString stringWithFormat:@"ignoring unknown accelerate speed string: %@", speed]];
		return;
	}
	
	DDLogVerbose(@"SceneManager: accel speed: %@", speed);
}

- (void)startGyroUpdates {
	if(self.scene.supportsGyro) {
		self.enableGyro = YES;
	}
}

- (void)stopGyroUpdates {
	if(self.scene.supportsGyro) {
		self.enableGyro = NO;
	}
}

- (void)setGyroSpeed:(NSString *)speed {

	if([speed isEqualToString:@"slow"]) {
		[motionManager setGyroUpdateInterval:1.0/SENSOR_UI_HZ];
	}
	else if([speed isEqualToString:@"normal"]) {
		[motionManager setGyroUpdateInterval:1.0/SENSOR_NORMAL_HZ];
	}
	else if([speed isEqualToString:@"fast"]) {
		[motionManager setGyroUpdateInterval:1.0/SENSOR_GAME_HZ];
	}
	else if([speed isEqualToString:@"fastest"]) {
		[motionManager setGyroUpdateInterval:1.0/SENSOR_FASTEST_HZ];
	}
	else {
		[self.pureData sendPrint:[NSString stringWithFormat:@"ignoring unknown gyro speed string: %@", speed]];
		return;
	}
	
	DDLogVerbose(@"SceneManager: gyro speed: %@", speed);
}

- (void)startMagnetUpdates {
	if(self.scene.supportsMagnet) {
		self.enableMagnet = YES;
	}
}

- (void)stopMagnetUpdates {
	if(self.scene.supportsMagnet) {
		self.enableMagnet = NO;
	}
}

- (void)setMagnetSpeed:(NSString *)speed {

	if([speed isEqualToString:@"slow"]) {
		[motionManager setMagnetometerUpdateInterval:1.0/SENSOR_UI_HZ];
	}
	else if([speed isEqualToString:@"normal"]) {
		[motionManager setMagnetometerUpdateInterval:1.0/SENSOR_NORMAL_HZ];
	}
	else if([speed isEqualToString:@"fast"]) {
		[motionManager setMagnetometerUpdateInterval:1.0/SENSOR_GAME_HZ];
	}
	else if([speed isEqualToString:@"fastest"]) {
		[motionManager setMagnetometerUpdateInterval:1.0/SENSOR_FASTEST_HZ];
	}
	else {
		[self.pureData sendPrint:[NSString stringWithFormat:@"ignoring unknown magnet speed string: %@", speed]];
		return;
	}
	
	DDLogVerbose(@"SceneManager: magnet speed: %@", speed);
}

- (void)startLocationUpdates {
	if(self.scene.supportsLocate) {
		self.enableLocation = YES;
	}
}

- (void)stopLocationUpdates {
	if(self.scene.supportsLocate) {
		self.enableLocation = NO;
	}
}

- (void)setLocationAccuracy:(NSString *)accuracy {
	
	if([accuracy isEqualToString:@"navigation"]) {
		locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
	}
	else if([accuracy isEqualToString:@"best"]) {
		locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	}
	else if([accuracy isEqualToString:@"10m"]) {
		locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
	}
	else if([accuracy isEqualToString:@"100m"]) {
		locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
	}
	else if([accuracy isEqualToString:@"1km"]) {
		locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
	}
	else if([accuracy isEqualToString:@"3km"]) {
		locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
	}
	else {
		[self.pureData sendPrint:[NSString stringWithFormat:@"ignoring unknown locate accuracy string: %@", accuracy]];
		return;
	}
	
	DDLogVerbose(@"SceneManager: location accuracy: %@", accuracy);
}

- (void)setLocationFilter:(float)distance {
	if(distance > 0 ) {
		locationManager.distanceFilter = distance;
		DDLogVerbose(@"SceneManager: location distance filter: +/- %f", distance);
	}
	else { // clip 0 & negative values
		locationManager.distanceFilter = kCLDistanceFilterNone;
		DDLogVerbose(@"SceneManager: location distance filter: none");
	}
}

- (void)startHeadingUpdates {
	if(self.scene.supportsHeading) {
		self.enableHeading = YES;
	}
}

- (void)stopHeadingUpdates {
	if(self.scene.supportsHeading) {
		self.enableHeading = NO;
	}
}

- (void)setHeadingFilter:(float)degrees {
	if(degrees > 0 ) {
		locationManager.headingFilter = degrees;
		DDLogVerbose(@"SceneManager: heading filter: +/- %f", degrees);
	}
	else { // clip 0 & negative values
		locationManager.headingFilter = kCLHeadingFilterNone;
		DDLogVerbose(@"SceneManager: heading filter: none");
	}
}

@end