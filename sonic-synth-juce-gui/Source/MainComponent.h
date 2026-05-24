#pragma once

#include <JuceHeader.h>
#include "SoundSourceDetector.h"

//==============================================================================
/*
    This component lives inside our window, and this is where you should put all
    your controls and content.
*/
class MainComponent  : public juce::Component,
    public juce::OSCReceiver::Listener<juce::OSCReceiver::RealtimeCallback>,
    public juce::Logger
{
public:
    //==============================================================================
    MainComponent();
    ~MainComponent() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;
    
    void oscMessageReceived(const juce::OSCMessage& message) override;

    void changeInstrument(const juce::String& newInstrument);
private:
    // OSC sender instance.
    juce::OSCSender oscSender;
    
    // OSC receiver instance.
    juce::OSCReceiver oscReceiver;
    
    // Sound source detector instance
    SoundSourceDetector detector;

    // log window for UI
    juce::TextEditor logWindow;

	juce::String triggerAddress = "/juce/triggerNote";
	juce::String instrumentSliderAddress = "/juce/slider";

    void logMessage(const juce::String& message) override;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};
