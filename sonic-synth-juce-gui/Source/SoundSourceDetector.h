/*
  ==============================================================================

    ObjectDetector.h
    Created: 22 May 2026 1:07:37pm
    Author:  diges

  ==============================================================================
*/

#pragma once

#include "SoundSource.h"

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
	float maxDistance = 100.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SoundSourceDetector)
};
