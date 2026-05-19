import processing.serial.*;
import oscP5.*;
import netP5.*;
import controlP5.*;

OscP5 oscP5;          // The OscP5 networking object
NetAddress myRemoteLocation; // Where we are sending the OSC messages
int buttonSize = 93;
int buttonX, buttonY;
color buttonColor = color(255);
boolean buttonOver = false;
int sonarDistance, sonarAngle;

ControlP5 cp5; // text input handler


void setup() {
  size(400, 400); // Small window just to keep the sketch running
    
  // We start oscP5 listening on port 12000 (standard setup, even if we just send)
  oscP5 = new OscP5(this, 12000);
  
  buttonX = width/2;
  buttonY = height/4;
  ellipseMode(CENTER);
  
  // Set the destination IP and Port.
  // "127.0.0.1" means "this same computer" (localhost). 
  // 7000 is the port your receiving app (like MaxMSP, TouchDesigner, or Unreal) is listening on.
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);
  
  cp5 = new ControlP5(this);
  
  // Create the input field
  cp5.addTextfield("angle")
     .setPosition(25, 200)
     .setSize(200, 40)
     .setFont(createFont("arial", 16))
     .setAutoClear(false) // Keeps the text in the box after pressing Enter
     .setColor(color(255));
     
  cp5.addTextfield("distance")
     .setPosition(25, 300)
     .setSize(200, 40)
     .setFont(createFont("arial", 16))
     .setAutoClear(false) // Keeps the text in the box after pressing Enter
     .setColor(color(255));
}

void draw() {
  updateMouse(mouseX, mouseY);
  background(0); // Just a visual indicator that the app is alive
  
  fill(buttonColor);
  stroke(0);
  ellipse(buttonX, buttonY, buttonSize, buttonSize);  
  
  textSize(16);
  fill(255);
}

void mousePressed() {
  if (buttonOver) {
     OscMessage message = new OscMessage("/sonar");
     
     message.add(sonarAngle);
     message.add(sonarDistance);
     
     oscP5.send(message, myRemoteLocation); // Send it!
     System.out.println("sent message:");
     message.print();
  }
}

void updateMouse(int x, int y) {
  if ( overButton(x, y, buttonSize) ) {
    buttonOver = true;
  } else {
    buttonOver = false;
  }
}

void angle(String newAngle) {
   try {
      sonarAngle = Integer.parseInt(newAngle);
   } catch (NumberFormatException e) {
     sonarAngle = 0; 
   }
    
   System.out.println(sonarAngle);
}

void distance(String newDistance) {
   try {
     sonarDistance = Integer.parseInt(newDistance); 
   } catch (NumberFormatException e) {
     sonarDistance = 0; 
   }
}

boolean overButton(int x, int y, int diameter) {
  float disX = x - buttonX;
  float disY = y - buttonY;
  if (sqrt(sq(disX) + sq(disY)) < diameter/2 ) {
    return true;
  } else {
    return false;
  }
}
