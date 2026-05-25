#include "MainComponent.h"
#include "Logging.h"
#include "SoundSource.h"
#include "SonarParameters.h"

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

			minMaxParam angleParam;
			minMaxParam distanceParam;
			if (instrumentSelected == "waves") {
				angleParam = instrumentParams::waveParams[angleParameter];
				distanceParam = instrumentParams::waveParams[distanceParameter];
			}
			else {
				angleParam = instrumentParams::bellParams[angleParameter];
				distanceParam = instrumentParams::bellParams[distanceParameter];
			}

			float param1Val = calculateParameterValue(angleParam, message[0].getInt32(), defaultValues::minAngle, defaultValues::maxAngle);
			float param2Val = calculateParameterValue(distanceParam, message[1].getInt32(), defaultValues::minDistance, defaultValues::maxDistance);

			juce::OSCMessage messageToSend(triggerAddress);
			messageToSend.addArgument(angleParam.name);
			messageToSend.addArgument(param1Val);
			messageToSend.addArgument(distanceParam.name);
			messageToSend.addArgument(param2Val);

			oscSender.send(messageToSend);
			LOG_INFO("Sent OSC message with values: " + angleParam.name + " " + juce::String(param1Val) + ", " + distanceParam.name + " " + juce::String(param2Val));
		}
		else {
			LOG_WARN("Received an unexpected number of arguments: " + message.size());
		}
	}
	else if (address == "/waveform") {
		if (message.size() == 1)
		{
			float sliderValue = message[0].getFloat32();
			LOG_INFO("Received slider OSC message with value: " + juce::String(sliderValue));

			juce::OSCMessage messageToSend("/juce/slider");
			messageToSend.addArgument(sliderValue);

			oscSender.send(messageToSend);
		}
		else {
			LOG_WARN("Received an unexpected number of arguments: " + message.size());
		}
	}
	else if (address == "/reverb/mix") {
		float sliderValue = message[0].getFloat32();
		LOG_INFO("Received bell mix slider OSC message with value: " + juce::String(sliderValue));

		juce::OSCMessage messageToSend("/juce/reverb");
		messageToSend.addArgument(sliderValue);

		oscSender.send(messageToSend);
		// TODO
		// 0-1
	}
	else if (address == "/reverb/decay") {
		// TODO
		// 0-10
	}
	else if (address == "/max_dist") {
		float newMaxDistance = message[0].getFloat32();
		LOG_INFO("Received max distance slider OSC message with value: " + juce::String(newMaxDistance));
		maxDistance = newMaxDistance;
	}
	else if (address == "/instrument") {
		LOG_INFO("Received instrument change OSC message with value: " + message[0].getInt32());
		if (message[0].getInt32() == 0) {
			changeInstrument("waves");
		}
		else if (message[0].getInt32() == 1) {
			changeInstrument("bells");
		}
	}
	else if (address == "/mapping/angle") {
		int newAngleParam = message[0].getInt32();
		LOG_INFO("Received angle mapping OSC message with value: " + juce::String(newAngleParam));
		angleParameter = newAngleParam;
	}
	else if (address == "/mapping/distance") {
		int newDistanceParam = message[0].getInt32();
		LOG_INFO("Received distance mapping OSC message with value: " + juce::String(newDistanceParam));
		distanceParameter = newDistanceParam;
	}
	else if (address == "/sample_skip/active") {
		//TODO int 0-1
	}
	else if (address == "/sample_skip/count") {
		//TODO int 10-60
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
		instrumentSelected = "waves";
	}
	else if (newInstrument == "bells") {
		triggerAddress = "/juce/triggerBell";
		instrumentSliderAddress = "/juce/reverb";
		instrumentSelected = "bells";
	}
	else {
		LOG_WARN("Attempted to change to unrecognized instrument: " + newInstrument);
	}
}

float MainComponent::calculateParameterValue(minMaxParam parameter, int sonarValue, float minSonarVal, float maxSonarVal)
{
	if (parameter.name == "freq") {
		// special handling for frequency parameter to quantize it to semitones
		// divide the sonar value into 12 semitones
		int semitone = (sonarValue * 12) / (maxSonarVal - minSonarVal);
		if (semitone > 12)
		{
			semitone = 12;
		}
		// compute the frequency using the formula: freq = minFreq * 2^(semitone/12)
		int freq = parameter.min * std::pow(2.0, semitone / 12.0);

		return freq;
	}
	// map the sonar value to a 0-1 range based on the expected min and max sonar values
	float normalizedValue = (sonarValue - minSonarVal) / (maxSonarVal - minSonarVal);
	// scale and shift the normalized value to fit within the parameter's expected range
	float scaledValue = parameter.min + normalizedValue * (parameter.max - parameter.min);
	return scaledValue;
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
