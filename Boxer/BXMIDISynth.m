/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXMIDISynth.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


#pragma mark -
#pragma mark Private method declarations

@interface BXMIDISynth ()

@property (readwrite, copy, nonatomic) NSURL *soundFontURL;

- (BOOL) _prepareAudioEngineWithError: (NSError **)outError;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXMIDISynth
{
    AVAudioEngine        *_engine;
    AVAudioUnitSampler   *_sampler;
}

#pragma mark -
#pragma mark Initialization and cleanup

- (instancetype) initWithError: (NSError **)outError
{
    if ((self = [self init]))
    {
        if (![self _prepareAudioEngineWithError: outError])
        {
            return nil;
        }
    }
    return self;
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    if (_engine)
    {
        [_engine stop];
    }
    _engine = nil;
    _sampler = nil;
}


- (BOOL) _prepareAudioEngineWithError: (NSError **)outError
{
    _sampler = [[AVAudioUnitSampler alloc] init];
    _engine  = [[AVAudioEngine alloc] init];

    [_engine attachNode: _sampler];
    [_engine connect: _sampler to: _engine.mainMixerNode format: nil];

    NSError *startError;
    if (![_engine startAndReturnError: &startError])
    {
        _engine = nil;
        _sampler = nil;
        if (outError) *outError = startError;
        return NO;
    }

    // A missing or unloadable system soundfont is non-fatal: the engine runs silent.
    NSURL *defaultFont = [self.class defaultSoundFontURL];
    if (defaultFont && [_sampler loadSoundBankInstrumentAtURL: defaultFont
                                                      program: 0
                                                      bankMSB: 0x79
                                                      bankLSB: 0
                                                        error: NULL])
    {
        self.soundFontURL = defaultFont;
    }

    return YES;
}


#pragma mark -
#pragma mark MIDI processing and status

- (BOOL) supportsMT32Music          { return NO; }
- (BOOL) supportsGeneralMIDIMusic   { return YES; }


//The MIDI synth is *always* ready to party
- (BOOL) isProcessing       { return NO; }
- (NSDate *) dateWhenReady  { return [NSDate distantPast]; }

- (void) handleMessage: (NSData *)message
{
    NSAssert(_sampler != nil, @"handleMessage: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleMessage:");

    UInt8 *contents = (UInt8 *)message.bytes;
    UInt8 status = contents[0];
    UInt8 data1 = (message.length > 1) ? contents[1] : 0;
    UInt8 data2 = (message.length > 2) ? contents[2] : 0;

    MusicDeviceMIDIEvent(_sampler.audioUnit, status, data1, data2, 0);
}

- (void) handleSysex: (NSData *)message
{
    NSAssert(_sampler != nil, @"handleSysEx: called before successful initialization.");
    NSAssert(message.length > 0, @"0-length message received by handleSysex:");

    MusicDeviceSysEx(_sampler.audioUnit, (const UInt8 *)message.bytes, (UInt32)message.length);
}

- (void) pause
{
    NSAssert(_engine != nil, @"pause called before successful initialization.");
    [_engine pause];
}

- (void) resume
{
    NSAssert(_engine != nil, @"resume called before successful initialization.");
    [_engine startAndReturnError: NULL];
}

- (void) setVolume: (float)volume
{
    NSAssert(_engine != nil, @"setVolume: called before successful initialization.");
    _engine.mainMixerNode.outputVolume = volume;
}

- (float) volume
{
    NSAssert(_engine != nil, @"volume called before successful initialization.");
    return _engine.mainMixerNode.outputVolume;
}


#pragma mark -
#pragma mark Soundfonts

+ (NSURL *) defaultSoundFontURL
{
    NSBundle *coreAudioBundle = [NSBundle bundleWithIdentifier: @"com.apple.audio.units.Components"];

    // Try the traditional DLS file first, then the SF2 fallback.
    NSURL *soundFontURL = [coreAudioBundle URLForResource: @"gs_instruments" withExtension: @"dls"];
    if (!soundFontURL)
        soundFontURL = [coreAudioBundle URLForResource: @"GeneralMIDI" withExtension: @"sf2"];

    return soundFontURL;
}

- (BOOL) loadSoundFontWithContentsOfURL: (NSURL *)URL
                                  error: (NSError **)outError
{
    NSAssert(_sampler != nil, @"loadSoundFontWithContentsOfURL:error: called before successful initialization.");

    //If we're clearing the soundfont, reset it back to the default system soundfont.
    if (URL == nil)
    {
        URL = [self.class defaultSoundFontURL];
        //Give up if the default soundfont could not be found.
        if (URL == nil)
        {
            if (outError)
            {
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileReadNoSuchFileError
                                            userInfo: nil];
            }
            return NO;
        }
    }
    else
    {
        URL = URL.URLByStandardizingPath;

        //Check that the URL even exists before proceeding further.
        BOOL resourceExists = [URL checkResourceIsReachableAndReturnError: outError];
        if (!resourceExists) return NO;
    }

    if (![URL isEqual: self.soundFontURL])
    {
        BOOL success = [_sampler loadSoundBankInstrumentAtURL: URL
                                                      program: 0
                                                      bankMSB: 0x79
                                                      bankLSB: 0
                                                        error: outError];
        if (!success)
        {
            //If the soundfont cannot be loaded, revert to the previous soundfont.
            if (self.soundFontURL)
            {
                [_sampler loadSoundBankInstrumentAtURL: self.soundFontURL
                                               program: 0
                                               bankMSB: 0x79
                                               bankLSB: 0
                                                 error: NULL];
            }
            return NO;
        }

        self.soundFontURL = URL;
        return YES;
    }
    else return YES;
}

@end
