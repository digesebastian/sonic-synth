import processing.serial.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;          // The OscP5 networking object
NetAddress myRemoteLocation; // Where we are sending the OSC messages

void setup() {
  size(200, 200); // Small window just to keep the sketch running
    
  // 3. Initialize OSC. 
  // We start oscP5 listening on port 12000 (standard setup, even if we just send)
  oscP5 = new OscP5(this, 12000);
  
  // 4. Set the destination IP and Port.
  // "127.0.0.1" means "this same computer" (localhost). 
  // 7000 is the port your receiving app (like MaxMSP, TouchDesigner, or Unreal) is listening on.
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);
  OscMessage myMessage = new OscMessage("/test");
    
  myMessage.add(440.0); // Add the data to the message
    
  oscP5.send(myMessage, myRemoteLocation); // Send it!
  System.out.println("sent message?");
}

void draw() {
  background(0); // Just a visual indicator that the app is alive
}
