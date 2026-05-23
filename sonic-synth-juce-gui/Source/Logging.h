/*
  ==============================================================================

    This file defines some logging macros

  ==============================================================================
*/

#pragma once
#include <JuceHeader.h>

// Log macros that format messages nicely with prefixes
#define LOG_INFO(msg)  juce::Logger::writeToLog("[INFO] "  + juce::String(msg))
#define LOG_WARN(msg)  juce::Logger::writeToLog("[WARN] "  + juce::String(msg))
#define LOG_ERROR(msg) juce::Logger::writeToLog("[ERROR] " + juce::String(msg))
