import processing.serial.*;
import oscP5.*;
import netP5.*;

Serial myPort;        // The Serial object
OscP5 oscP5;          // The OscP5 networking object
NetAddress myRemoteLocation; // Where we are sending the OSC messages

void setup() {
  size(200, 200); // Small window just to keep the sketch running
  
  // 1. List all available serial ports in the console
  printArray(Serial.list());
  
  // 2. Open the port your Arduino is connected to.
  // Change the [0] to match the index of your Arduino from the console list.
  String portName = Serial.list()[0]; 
  myPort = new Serial(this, portName, 9600);
  
  // Only trigger serialEvent when a newline character (\n) arrives
  myPort.bufferUntil('\n');
  
  // 3. Initialize OSC. 
  // We start oscP5 listening on port 12000 (standard setup, even if we just send)
  oscP5 = new OscP5(this, 12000);
  
  // 4. Set the destination IP and Port.
  // "127.0.0.1" means "this same computer" (localhost). 
  // 7000 is the port your receiving app (like MaxMSP, TouchDesigner, or Unreal) is listening on.
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);
}

void draw() {
  background(0); // Just a visual indicator that the app is alive
}

// This function runs automatically whenever new serial data arrives
void serialEvent(Serial myPort) {
  // Read the data until the newline character
  String inString = myPort.readStringUntil('\n');
  
  if (inString != null) {
    inString = trim(inString); // Trim whitespace/newlines
    
    // Convert the string to a number (assuming Arduino sent a sensor value)
    float sensorValue = float(inString);
    println("Received from Arduino: " + sensorValue); // Log it
    
    // --- SEND OSC MESSAGE ---
    // Create a new OSC message with an address tag (like a URL path)
    OscMessage myMessage = new OscMessage("/arduino/sensor");
    
    myMessage.add(sensorValue); // Add the data to the message
    
    oscP5.send(myMessage, myRemoteLocation); // Send it!
  }
}
