// =====================================================================
// 1. Boot Server and Clean Everything
// =====================================================================
s.boot;
thisProcess.removeOSCRecvFunc;
OSCdef.freeAll;

// =====================================================================
// 2. THE SYNTHDEF
// =====================================================================
(
SynthDef.new(\juceDrone, {
    arg freq = 440, amp = 0.5, atk = 2.0, sus = 6.0, rel = 8.0,
        detune = 0.005, filterStart = 2500, filterEnd = 800,
        waveShape = 2, out = 0;

    var snd, env, filterSweep, voices;

    env = EnvGen.kr(Env.linen(attackTime: atk, sustainTime: sus, releaseTime: rel, level: 1.0, curve: \sine), doneAction: 2);

    voices = 16.collect { |i|
        var octaveMultiplier, voiceFreq, oscArray, voice, voiceShapeOffset;

        octaveMultiplier = if(i % 2 == 0, 1, 2);
        voiceFreq = freq * octaveMultiplier * (1 + (LFNoise2.kr(8) * detune));

        oscArray = [
            SinOsc.ar(voiceFreq),
            LFTri.ar(voiceFreq),
            Saw.ar(voiceFreq),
            Pulse.ar(voiceFreq, 0.5)
        ];

        voiceShapeOffset = (waveShape + Rand(-0.4, 0.4)).clip(0, 3);
        voice = SelectX.ar(voiceShapeOffset, oscArray);

        DelayC.ar(voice, 0.02, Rand(0.001, 0.02));
    };

    snd = Splay.ar(voices);

    filterSweep = XLine.kr(start: filterStart, end: max(filterEnd, freq * 1.5), dur: atk + sus);
    snd = LPF.ar(snd, filterSweep);

    snd = snd + PitchShift.ar(snd, windowSize: 0.2, pitchRatio: 0.5, pitchDispersion: 0.0, timeDispersion: 0.1);
    snd = FreeVerb2.ar(snd[0], snd[1], mix: 0.4, room: 0.9, damp: 0.8);

    snd = snd * env * amp;
    snd = Limiter.ar(snd, level: 0.9);

    Out.ar(out, snd);
}).add;
)

/// =====================================================================
// 3. Message Recieving
// =====================================================================
(
~activeDrones = Dictionary.new;

// LISTENER 1: Handles incoming Note Triggers with Key-Value pairs
OSCdef.new(\noteTriggerListener, { |msg|
    var synthArgs, newSynth;

    // msg.drop(1) deletes the '/juce/triggerNote' address from the array.
    // It leaves us with a perfect list of names and values to inject directly!
    synthArgs = msg.drop(1);

    // Spawn the synth. Anything skipped by JUCE automatically uses your SynthDef defaults.
    newSynth = Synth(\juceDrone, synthArgs);

    // Track it for the polyphonic slider
    ~activeDrones.put(newSynth.nodeID, newSynth);
    NodeWatcher.register(newSynth);

    newSynth.onFree {
        ~activeDrones.removeAt(newSynth.nodeID);
        ("Note finished. Cleaned ID: " ++ newSynth.nodeID).postln;
    };

    ("Triggered Note ID: " ++ newSynth.nodeID ++ " with args: " ++ synthArgs).postln;

}, '/juce/triggerNote');


// LISTENER 2: Handles the polyphonic slider updates
OSCdef.new(\sliderUpdateListener, { |msg|
    var incomingValue = msg[1];

    // Morph all active drones simultaneously!
    ~activeDrones.do({ |synth|
        synth.set(\waveShape, incomingValue);
    });

    ("Slider moved to " ++ incomingValue ++ ". Morphed " ++ ~activeDrones.size ++ " notes.").postln;

}, '/juce/slider');

"--- SMART KEY-VALUE ENGINE ACTIVE: Waiting for JUCE ---".postln;
)

// =====================================================================
// 4. Test Area
// =====================================================================
(
Synth(\juceDrone, [\freq, 73.42,  \atk, 4, \sus, 45, \rel, 6, \amp, 0.4, \waveShape, 0.0]);
Synth(\juceDrone, [\freq, 110.00, \atk, 4, \sus, 45, \rel, 6, \amp, 0.3, \waveShape, 0.0]);
Synth(\juceDrone, [\freq, 138.59, \atk, 4, \sus, 45, \rel, 6, \amp, 0.2, \waveShape, 0.0]);
)


~activeDrones.do({ |synth| synth.set(\waveShape, 1.0) });
~activeDrones.do({ |synth| synth.set(\waveShape, 2.0) });
~activeDrones.do({ |synth| synth.set(\waveShape, 3.0) });
~activeDrones.do({ |synth| synth.set(\waveShape, 1.7) });
~activeDrones.do({ |synth| synth.set(\waveShape, 0.0) });
Synth(\juceDrone, [\freq, 110, \atk, 4, \sus, 50, \rel, 6, \amp, 0.4, \waveShape, 0]);
Synth(\juceDrone, [\freq, 440, \atk, 3, \sus, 5, \rel, 4]);
Synth(\juceDrone, [\freq, 350, \atk, 10, \sus, 40, \rel, 10]);
Synth(\juceDrone, [\freq, 580, \atk, 0.1, \sus, 0.4, \rel, 0.5]);
Synth(\juceDrone, [\freq, 880, \atk, 0.1, \sus, 0.4, \rel, 0.5]);
Synth(\juceDrone, [\freq, 440, \atk, 0.1, \sus, 10, \rel, 0.5, \waveShape, 2, \amp, ]);
Synth(\juceDrone, [\freq, 440, \atk, 0.1, \sus, 5, \rel, 0.4, \waveShape, 1]);
Synth(\juceDrone, [\freq, 440, \atk, 0.1, \sus, 5, \rel, 0.4, \waveShape, 2]);
Synth(\juceDrone, [\freq, 440, \atk, 0.1, \sus, 5, \rel, 0.4, \waveShape, 3]);
Synth(\juceDrone, [\freq, 440, \atk, 0.1, \sus, 5, \rel, 0.4, \waveShape, 0]);
Synth(\juceDrone, [\freq, 110, \atk, 4, \sus, 6, \rel, 6, \waveShape, 2,]);
Synth(\juceDrone, [\freq, 110, \atk, 4, \sus, 6, \rel, 6, \waveShape, 3, \amp, 0.4]);
