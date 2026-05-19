(
OSCFunc.newMatching({ |msg, time, addr, recvPort|
    "Received OSC Message: ".post;
    msg.postln; // This will print [/juce/test, 440.0]
}, '/juce/sonar');
)
