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

#import "Midi.h"

/// midi settings view
@interface MidiViewController : UITableViewController <MidiConnectionDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *midiEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *networkMidiEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *virtualInputEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *virtualOutputEnabledSwitch;

- (IBAction)enableMidi:(id)sender;
- (IBAction)enableNetworkMidi:(id)sender;
- (IBAction)enableVirtualInput:(id)sender;
- (IBAction)enableVirtualOutput:(id)sender;

@end
