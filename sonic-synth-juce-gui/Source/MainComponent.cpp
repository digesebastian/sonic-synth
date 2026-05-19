#include "MainComponent.h"
#include "Logging.h"

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
			int value1 = message[0].getInt32();
			LOG_INFO("Received OSC message with value: " + juce::String(value1));

			int value2 = message[1].getInt32();
			LOG_INFO("Received OSC message with value: " + juce::String(value2));

			juce::OSCMessage messageToSend ("/juce/sonar");
			messageToSend.addArgument(value1);
			messageToSend.addArgument(value2);

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
