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

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SoundSourceDetector)
};
