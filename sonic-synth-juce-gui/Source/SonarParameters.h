/*
  ==============================================================================

    SonarParameters.h
    Created: 25 May 2026 3:01:13pm
    Author:  diges

  ==============================================================================
*/

#pragma once
#include <juce_core/juce_core.h>

struct minMaxParam {
	juce::String name;
	float min;
	float max;
};

namespace instrumentParams {
    inline const std::array<minMaxParam, 4> waveParams = {
        minMaxParam{"freq", 110.0f, 220.0f},
        minMaxParam{"sus", 6.0f, 60.0f},
        minMaxParam{"rel", 0.8f, 30.0f},
        minMaxParam{"amp", 0.0f, 1.0f}
    };

    inline const std::array<minMaxParam, 5> bellParams = {
        minMaxParam{"freq", 220.0f, 440.0f},
        minMaxParam{"mRatio", 1.0f, 12.0f},
        minMaxParam{"mLevel", 1.0f, 10.0f},
        minMaxParam{"rel", 0.8f, 30.0f},
        minMaxParam{"detune", 0.0f, 5.0f}
    };
}