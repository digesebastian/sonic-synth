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
}

MainComponent::~MainComponent()
{
    oscReceiver.removeListener(this);

	oscReceiver.disconnect();

	LOG_INFO("disconnected");
}

void MainComponent::oscMessageReceived(const juce::OSCMessage& message)
{
	if (message.getAddressPattern() == "/sonar")
	{
		if (message.size() == 2)
		{
			std::optional<SoundSource> potentialSource = detector.checkForNewSource(message[0].getInt32(), message[1].getInt32());
			if (!potentialSource.has_value())
			{
				return; // no new sound source detected, so we can exit early
			}
			SoundSource newSource = potentialSource.value();

			juce::OSCMessage messageToSend("/juce/triggerNote");
			messageToSend.addArgument(juce::String("freq"));
			messageToSend.addArgument(newSource.freq);

			messageToSend.addArgument(juce::String("atk"));
			messageToSend.addArgument(4);

			messageToSend.addArgument(juce::String("sus"));
			messageToSend.addArgument(40);

			messageToSend.addArgument(juce::String("rel"));
			messageToSend.addArgument(6);

			oscSender.send(messageToSend);
		}
		else {
			LOG_WARN("Received an unexpected number of arguments: " + message.size());
		}
	}
	else if (message.getAddressPattern() == "/instrumentSlider") {
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
	else {
		LOG_WARN("Received OSC message with unrecognized address pattern: " + message.getAddressPattern().toString());
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
}
