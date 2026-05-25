
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

//BELL AND REVERB SYNTHDEFS
SynthDef(\fm_2, {
	arg freq=220, mRatio=9, cRatio=1, index=1, mLevel=5,
	amp=0.2, atk=0.01, rel=0.7, cAtk=5, cRel=(-4), pan=0, out=0, detune=1.5, spread=0.8;

	var car, mod, env, iEnv, detunedVoices;

	//modulation index
	iEnv = EnvGen.kr(
		Env(
			[index, index*mLevel, index],
			[atk, rel],
			[cAtk, cRel]
		)
	);

	//amplitude envelope
	env = EnvGen.kr(Env.perc(atk, rel,curve:[cAtk, cRel]), doneAction:2);
	detunedVoices = [-2, -1, 0, 1, 2] * detune; //initialize 5 voice unison detune with frequency offset value for each voice multiplied by detune amount

	//modulator carrier
	mod = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);
	car = SinOsc.ar(freq * cRatio + detunedVoices + mod);

	car = Splay.ar(car, spread: spread, center: pan, levelComp: true); //spread voices across stereo field
	car = car * env * amp;

	//car = Pan2.ar(car, pan);

	//direct outd
	Out.ar(out, car);
	//Out.ar(fx, car * fxsend.dbamp); //for reverb send if needed

}).add;

//suggested reverb parameters to change: reverbDecay (decay time), size
SynthDef(\jp_reverb, {
	arg in, reverbDecay=2, out=0, roomsize=1.0, damp=0.1, size = 2.5, reverbMix=0.5;
	var snd, dry, wet;

	snd = In.ar(in, 2);
	dry = snd;

	wet = JPverb.ar(
		snd.sum,
		t60: reverbDecay,
		size: roomsize,
		damp: damp,
		modDepth: 0.7,
		modFreq: 2
	);

	//mix
	//snd = wet + dry;
	snd = XFade2.ar(dry, wet, (reverbMix * 2) - 1);
	snd = snd * -15.dbamp;
	Out.ar(out,snd);
}).add;

SynthDef(\tape_delay, {
	//delayTime -> 0.01-2
	arg in, out=0, delayTime=0.3, fdbk=0.6, delayMix=0.4;
	var dry, wet, local;

	dry = In.ar(in, 2); //setup input
	local = LocalIn.ar(2) + dry; //setup feedback loop

	wet = DelayC.ar(local, 2.0, delayTime);



	LocalOut.ar(wet * fdbk);
	Out.ar(out, XFade2.ar(dry, wet, (delayMix * 2) - 1));

}).add;

)

/// =====================================================================
// 3. Message Recieving
// =====================================================================
(
~activeDrones = Dictionary.new; //setup
~bellBus = Bus.audio(s, 2); //bus for bells
~reverbBus = Bus.audio(s, 2); //bus for Delay to Reverb
~delayOut = Synth.tail(s, \tape_delay, [\in, ~bellBus, \out, ~reverbBus, \delayMix, 0.4]);
~reverbOut = Synth.tail(s, \jp_reverb, [\in, ~reverbBus, \out, 0, \reverbMix, 0.5, \reverbDecay, 2]); //global reverb variable

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

//ANTONIO's LISTENER
OSCdef.new(\bellTrigger, {|msg|
	var bellArgs, newBellSynth;
	bellArgs = msg.drop(1); //isolate just parameter list

	newBellSynth = Synth(\fm_2, bellArgs ++ [\out, ~bellBus]); //++ to concatenate
	("Bells triggered with args: " ++ bellArgs).postln; //debug print

}, '/juce/triggerBell');

//Reverb Listener
OSCdef.new(\reverbTrigger, {|msg|
	var reverbArgs;

	reverbArgs = msg.drop(1);
	if (~reverbOut.notNil) {
		~reverbOut.set(*reverbArgs);
		("Updated reverb with args: " ++ reverbArgs).postln;
	};

}, '/juce/reverb');

//Delay Listener
OSCdef.new(\delayTrigger, {|msg|
	var delayArgs;

	delayArgs = msg.drop(1);
	if (~delayOut.notNil) {
		~delayOut.set(*delayArgs);
		("Delay updated with args: " ++ delayArgs).postln;
	};
}, '/juce/delay');

//Bell+Reverb Combo
OSCdef.new(\bellReverbComboTrigger, { |msg|
	var comboArgs;

	comboArgs = msg.drop(1);
	if (~reverbOut.notNil) {
		~reverbOut.set(*comboArgs);
	};

	if (~delayOut.notNil) {
		~delayOut.set(*comboArgs);
	};

	Synth(\fm_2, comboArgs ++ [\out, ~bellBus]);

	("Bells and Reverb triggered with args: " ++ comboArgs).postln;


}, '/juce/combo');


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


//Bell and Reverb Tests
// Create a fake "JUCE" network address pointing at SuperCollider's own port
~fakeJuce = NetAddr("127.0.0.1", NetAddr.langPort);

//bell tests
~fakeJuce.sendMsg('/juce/triggerBell', \freq, 800, \mLevel, 4, \rel, 0.5);
~fakeJuce.sendMsg('/juce/triggerBell', \freq, 220, \mLevel, 4, \rel, 1, \mRatio, 10, \detune, 1.5, \spread, 10);
~fakeJuce.sendMsg('/juce/triggerBell', \freq, 400, \mLevel, 10, \rel, 1.2);

//large reverb
~fakeJuce.sendMsg('/juce/reverb', \reverbMix, 0.9, \reverbDecay, 8.0);

//higher bell
~fakeJuce.sendMsg('/juce/triggerBell', \freq, 1200, \mLevel, 3);

//lower mix
~fakeJuce.sendMsg('/juce/reverb', \reverbMix, 0.2, \reverbDecay, 1.0);

//test combo
~fakeJuce.sendMsg('/juce/combo', \freq, 800, \mLevel, 8, \reverbMix, 0.5, \reverbDecay, 1.0);

//test new combo
~fakeJuce.sendMsg('/juce/combo', \freq, 330, \delayTime, 0.7, \feedback, 0.4, \delayMix, 0.7, \reverbDecay, 1.0);
