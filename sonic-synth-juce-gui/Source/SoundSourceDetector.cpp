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
	if (distance <= maxDistance && minAngle < angle && angle < maxAngle)
	{
		currentSourceData.push_back(std::make_tuple(angle, distance));
		if (currentlyScanningSource)
		{
			int sourceSize = currentSourceData.size();
			if (useMaxSourceSize && sourceSize > maxSourceSize)
			{
				SoundSource newSource{};
				newSource.angle = std::get<0>(currentSourceData[sourceSize / 2]);
				newSource.distance = std::get<1>(currentSourceData[sourceSize / 2]);

				LOG_INFO("Max object size exceeded. Playing source of size " + juce::String(sourceSize)
					+ " at angle " + juce::String(newSource.angle)
					+ " and distance " + juce::String(newSource.distance));

				currentSourceData.clear();
				currentlyScanningSource = false;
				return std::make_optional(newSource);
			}
		} 
		else {
			currentlyScanningSource = true;
			LOG_INFO("Started detecting sound source");
		}
	}
	else if (currentlyScanningSource)
	{
		int sourceSize = currentSourceData.size();
		if (sourceSize < 4) {
			LOG_INFO("Discarded source of size " + std::to_string(sourceSize));
			currentSourceData.clear();
			currentlyScanningSource = false;
			return std::nullopt;
		}
		SoundSource newSource{};
		newSource.angle = std::get<0>(currentSourceData[sourceSize / 2]);
		newSource.distance = std::get<1>(currentSourceData[sourceSize / 2]);

		LOG_INFO("Playing source of size " + juce::String(sourceSize)
			+ " at angle " + juce::String(newSource.angle)
			+ " and distance " + juce::String(newSource.distance));

		currentSourceData.clear();
		currentlyScanningSource = false;
		return std::make_optional(newSource);
	}
    
	return std::nullopt;
}