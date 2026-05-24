/*
  ==============================================================================

    ObjectDetector.h
    Created: 22 May 2026 1:07:37pm
    Author:  diges

  ==============================================================================
*/

#pragma once

#include "SoundSource.h"

namespace defaultValues
{
	constexpr int maxDistance = 100;
	constexpr int minFreq = 440;
	constexpr int maxFreq = 880;
    constexpr int minAngle = 0;
    constexpr int maxAngle = 180;

}

class SoundSourceDetector
{
public:
    //==============================================================================
    SoundSourceDetector();
    ~SoundSourceDetector();

    //==============================================================================
    
    std::optional<SoundSource> checkForNewSource(const int& angle, const int& distance);

	void setMaxDistance(const float& newMaxDistance) { maxDistance = newMaxDistance; }

private:
    bool currentlyScanningSource = false;
	float maxDistance = defaultValues::maxDistance;

    int computeFreq(const int& angle);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SoundSourceDetector)
};
