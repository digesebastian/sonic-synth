#include "MainComponent.h"
#include "Logging.h"
#include "SoundSource.h"

//==============================================================================
MainComponent::MainComponent()
{
    setSize (600, 400);
    
    oscSender.connect("127.0.0.1", 57120);
	if (!oscReceiver.connect(7000))
	{
		// Handle error if the port is already in use
		LOG_ERROR("Error: Could not connect to UDP port 7000");
	}
	oscReceiver.addListener(this);

	// logging window setup
	logWindow.setMultiLine(true);
	logWindow.setReturnKeyStartsNewLine(true);
	logWindow.setReadOnly(true);
	logWindow.setScrollbarsShown(true);
	logWindow.setCaretVisible(false);
	addAndMakeVisible(logWindow);

	// Set this component as the current global logger
	juce::Logger::setCurrentLogger(this);

	// write initial log message
	juce::Logger::writeToLog("--- Logging messages ---");
}

MainComponent::~MainComponent()
{
    oscReceiver.removeListener(this);

	oscReceiver.disconnect();

	juce::Logger::setCurrentLogger(nullptr);

	LOG_INFO("disconnected");
}

void MainComponent::oscMessageReceived(const juce::OSCMessage& message)
{
	juce::String address = message.getAddressPattern().toString();
	if (address == "/sonar")
	{
		if (message.size() == 2)
		{
			std::optional<SoundSource> potentialSource = detector.checkForNewSource(message[0].getInt32(), message[1].getInt32());
			if (!potentialSource.has_value())
			{
				return; // no new sound source detected, so we can exit early
			}
			SoundSource newSource = potentialSource.value();
			int newFreq = newSource.freq;

			juce::OSCMessage messageToSend(triggerAddress);
			messageToSend.addArgument(juce::String("freq"));
			messageToSend.addArgument(newFreq);

			oscSender.send(messageToSend);
		}
		else {
			LOG_WARN("Received an unexpected number of arguments: " + message.size());
		}
	}
	else if (address == "/instrumentSlider") {
		if (message.size() == 1)
		{
			float sliderValue = message[0].getFloat32();
			LOG_INFO("Received slider OSC message with value: " + juce::String(sliderValue));

			juce::OSCMessage messageToSend(instrumentSliderAddress);
			messageToSend.addArgument(sliderValue);

			oscSender.send(messageToSend);
		}
		else {
			LOG_WARN("Received an unexpected number of arguments: " + message.size());
		}
	}
	else if (address == "/maxDistanceSlider") {
		float newMaxDistance = message[0].getFloat32();
		LOG_INFO("Received max distance slider OSC message with value: " + juce::String(newMaxDistance));
		detector.setMaxDistance(newMaxDistance);
	}
	else if (address == "/instrumentChange") {
		changeInstrument(message[0].getString());
	}
	else {
		LOG_WARN("Received OSC message with unrecognized address pattern: " + message.getAddressPattern().toString());
	}
}

void MainComponent::changeInstrument(const juce::String& newInstrument)
{
	if (newInstrument == "waves") {
		triggerAddress = "/juce/triggerNote";
		instrumentSliderAddress = "/juce/slider";
	}
	else if (newInstrument == "bells") {
		triggerAddress = "/juce/triggerBell";
		instrumentSliderAddress = "/juce/reverb";
	}
	else {
		LOG_WARN("Attempted to change to unrecognized instrument: " + newInstrument);
	}
}

//==============================================================================
void MainComponent::paint (juce::Graphics& g)
{
    // (Our component is opaque, so we must completely fill the background with a solid colour)
    g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));

    g.setFont (juce::FontOptions (16.0f));
    g.setColour (juce::Colours::white);
    g.drawText ("Hello World!", getLocalBounds(), juce::Justification::centred, true);
}

void MainComponent::resized()
{
    // This is called when the MainComponent is resized.
    // If you add any child components, this is where you should
    // update their positions.

	logWindow.setBounds(getLocalBounds().reduced(10));
}

// This callback captures ALL incoming log messages securely
void MainComponent::logMessage(const juce::String& message)
{
	// Because logging can occur from background threads, 
	// we MUST safely push the UI update to the main Message Thread.
	juce::MessageManager::callAsync([this, message]()
		{
			logWindow.moveCaretToEnd();
			logWindow.insertTextAtCaret(message + juce::newLine);
		});
}
