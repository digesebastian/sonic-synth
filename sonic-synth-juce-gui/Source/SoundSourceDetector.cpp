/*
  ==============================================================================

    ObjectDetector.cpp
    Created: 22 May 2026 1:07:37pm
    Author:  diges

  ==============================================================================
*/

#include "SoundSourceDetector.h"
#include "Logging.h"

SoundSourceDetector::SoundSourceDetector()
{
}

SoundSourceDetector::~SoundSourceDetector()
{
}

std::optional<SoundSource> SoundSourceDetector::checkForNewSource(const int& angle, const int& distance)
{
	if (distance < maxDistance)
	{
		if (!currentlyScanningSource)
		{
			LOG_INFO("New sound source detected at angle: " + juce::String(angle) + " and distance: " + juce::String(distance));
			currentlyScanningSource = true;
			SoundSource newSource;
			newSource.freq = angle;

			return newSource;
		}
		else {
			//LOG_INFO("Detected same sound source as before");
		}
	}
	else
	{
		LOG_INFO("Not detecting sound source");
		currentlyScanningSource = false;
	}
    
	return std::nullopt;
}