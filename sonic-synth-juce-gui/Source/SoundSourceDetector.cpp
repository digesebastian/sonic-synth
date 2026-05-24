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
			newSource.freq = computeFreq(angle);

			return newSource;
		}
		else {
			//LOG_INFO("Detected same sound source as before");
		}
	}
	else
	{
		if (currentlyScanningSource) {
			LOG_INFO("No longer detecting sound source");
		}
		currentlyScanningSource = false;
	}
    
	return std::nullopt;
}

int SoundSourceDetector::computeFreq(const int& angle)
{
	// divide the angle into 12 semitones
	int semitone = (angle * 12) / defaultValues::maxAngle;
	if (semitone > 12)
	{
		semitone = 12;
	}
	// compute the frequency using the formula: freq = minFreq * 2^(semitone/12)
	int freq = defaultValues::minFreq * std::pow(2.0, semitone / 12.0);

	return freq;
}