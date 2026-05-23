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
	constexpr int maxDistance = 100; // TODO: change this to the correct value
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

private:
    int maxDistance = defaultValues::maxDistance;
    bool currentlyScanningSource = false;

    int computeFreq(const int& angle);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SoundSourceDetector)
};
