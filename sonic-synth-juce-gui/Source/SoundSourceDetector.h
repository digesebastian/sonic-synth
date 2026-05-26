/*
  ==============================================================================

    ObjectDetector.h
    Created: 22 May 2026 1:07:37pm
    Author:  diges

  ==============================================================================
*/

#pragma once

#include "SoundSource.h"
#include <iostream>
#include <vector>

class SoundSourceDetector
{
public:
    //==============================================================================
    SoundSourceDetector();
    ~SoundSourceDetector();

    //==============================================================================
    
    std::optional<SoundSource> checkForNewSource(const int& angle, const int& distance);

	void setMaxDistance(const float& newMaxDistance) { maxDistance = newMaxDistance; }
	void setUseMaxSourceSize(const bool& shouldUseMaxSourceSize) { useMaxSourceSize = shouldUseMaxSourceSize; }
	void setMaxSourceSize(const int& newMaxSourceSize) { maxSourceSize = newMaxSourceSize; }

private:
    bool currentlyScanningSource = false;
	float maxDistance = 100.0f;

    bool useMaxSourceSize = false;
	int minAngle = 15;
	int maxAngle = 165;
    int maxSourceSize = 15;

	std::vector<std::tuple<int, int>> currentSourceData;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SoundSourceDetector);
};
