s.options.numInputBusChannels = 0;

(
SynthDef.new(\juceDrone, {
    // 1. Arguments: Explicitly defined for JUCE control
    arg freq = 440, amp = 0.5, atk = 2.0, sus = 6.0, rel = 8.0,
        detune = 0.005, filterStart = 2500, filterEnd = 200, out = 0;

    var snd, env, filterSweep, voices;

    // 2. The Automatic Envelope (Memory Management)
    // doneAction: 2 ensures the server memory is cleared when the release finishes.
    env = EnvGen.kr(Env.linen(attackTime: atk, sustainTime: sus, releaseTime: rel, level: 1.0, curve: \sine), doneAction: 2);

    // 3. The 16-Voice Cinematic Engine
    // We generate an array of 16 individual sawtooth waves.
    voices = 16.collect { |i|
        var octaveMultiplier, voiceFreq, voice;

        // Alternates between the root note (1) and one octave up (2)
        octaveMultiplier = if(i % 2 == 0, 1, 2);

        // Adds a slow, random pitch drift to every single voice independently
        voiceFreq = freq * octaveMultiplier * (1 + (LFNoise2.kr(8) * detune));
        voice = Saw.ar(voiceFreq);

        // Adds a tiny random delay to each voice to create a massive "chorus" width
        DelayC.ar(voice, 0.02, Rand(0.001, 0.02));
    };

    // Splay takes our 16 mono voices and spreads them beautifully across the stereo field
    snd = Splay.ar(voices);

    // 4. The "Filter Dive"
    // XLine creates a curve that sweeps from a bright frequency down to a dark rumble
    filterSweep = XLine.kr(start: filterStart, end: filterEnd, dur: atk + sus);
    snd = LPF.ar(snd, filterSweep);

    // 5. The Sub-Octave Generator
    // PitchShift duplicates the audio and pitches it down exactly one octave (ratio: 0.5)
    snd = snd + PitchShift.ar(snd, windowSize: 0.2, pitchRatio: 0.5, pitchDispersion: 0.0, timeDispersion: 0.1);

    // 6. Space and Dynamics
    // Using the built-in FreeVerb2 for true stereo reverb instead of a 3rd party plugin
    snd = FreeVerb2.ar(snd[0], snd[1], mix: 0.4, room: 0.9, damp: 0.8);

    // Apply envelope and volume, then use a Limiter so the 16 voices never clip the output
    snd = snd * env * amp;
    snd = Limiter.ar(snd, level: 0.9);

    // 7. Output
    Out.ar(out, snd);
}).add;
)
Synth(\juceDrone, [\freq, 110, \atk, 4, \sus, 50, \rel, 6, \amp, 0.4]);
Synth(\juceDrone, [\freq, 440, \atk, 3, \sus, 5, \rel, 4]);
Synth(\juceDrone, [\freq, 350, \atk, 10, \sus, 40, \rel, 10]);
Synth(\juceDrone, [\freq, 580, \atk, 0.1, \sus, 0.4, \rel, 0.5]);
Synth(\juceDrone, [\freq, 880, \atk, 0.1, \sus, 0.4, \rel, 0.5]);

/*(
SynthDef.new(\jucePad, {
    // 1. Arguments
    // Removed 'gate'. Added 'atk', 'sus', and 'rel' times (in seconds).
    arg freq = 440, amp = 0.5, atk = 3.0, sus = 5.0, rel = 4.0,
        detune = 0.1, wobbleRate = 0.001, wobbleDepth = 0.02, out = 0;

    var snd, env, wobble;

    // 2. The Automatic Envelope
    // Env.linen automatically runs through attack, sustain, and release phases.
    // As soon as 'rel' finishes, doneAction: 2 automatically deletes the synth.
    env = EnvGen.kr(Env.linen(attackTime: atk, sustainTime: sus, releaseTime: rel, level: 1.0, curve: \sine), doneAction: 2);

    // 3. Pitch Modulator
    wobble = LFNoise2.kr(wobbleRate) * wobbleDepth;

    // 4. Core Sound Engine
    snd = Mix.fill(5, {
        var voiceDetune, voiceFreq;
        voiceDetune = Rand(-1.0, 1.0) * detune;
        voiceFreq = freq * (1 + voiceDetune + wobble);

        Saw.ar(voiceFreq, 0.4) + SinOsc.ar(voiceFreq, 0, 0.6);
    });

    snd = snd / 8;

    // 5. Filtering
    snd = LPF.ar(snd, freq * 3.5);

    // 6. Apply Envelope and Amplitude
    snd = snd * env * amp;

    // 7. Stereo Spread and Reverb
    snd = Pan2.ar(snd, 0);
    snd = FreeVerb.ar(snd, mix: 0.55, room: 0.9, damp: 0.4);

    // 8. Audio Output
    Out.ar(out, snd);
}).add;
)
Synth(\jucePad, [\freq, 440, \atk, 3, \sus, 5, \rel, 4]);
Synth(\jucePad, [\freq, 350, \atk, 8, \sus, 12, \rel, 10, \amp, 0.6]);
Synth(\jucePad, [\freq, 580, \atk, 0.1, \sus, 0.4, \rel, 0.5]);*/