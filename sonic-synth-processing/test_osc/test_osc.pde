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
boolean sliderOver = false;
int sonarDistance, sonarAngle;

ControlP5 cp5; // text input handler

// Slider variables
float sliderX = 50;     // Current X position of the handle
float sliderY = 150;     // Y position of the track
float trackLeft = 50;   // Left boundary of the track
float trackRight = 350;  // Right boundary of the track
float handleSize = 20;   // Diameter of the slider handle
boolean isDragging = false;
// Variable we want to control (maps the slider position to a value)
float sliderValue = 0;


void setup() {
  size(400, 600); // Small window just to keep the sketch running
    
  // We start oscP5 listening on port 12000 (standard setup, even if we just send)
  oscP5 = new OscP5(this, 12000);
  
  buttonX = width/2;
  buttonY = 300;
  ellipseMode(CENTER);
  
  // Set the destination IP and Port.
  // "127.0.0.1" means "this same computer" (localhost). 
  // 7000 is the port your receiving app (like MaxMSP, TouchDesigner, or Unreal) is listening on.
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);
  
  cp5 = new ControlP5(this);
  
  // Create the input field
  cp5.addTextfield("angle")
     .setPosition(25, 400)
     .setSize(200, 40)
     .setFont(createFont("arial", 16))
     .setAutoClear(false) // Keeps the text in the box after pressing Enter
     .setColor(color(255));
     
  cp5.addTextfield("distance")
     .setPosition(25, 500)
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
  
  
  // slider
  // 1. Update the slider position if the user is dragging it
  if (isDragging) {
    // Constrain ensures the handle stays between the track limits
    sliderX = constrain(mouseX, trackLeft, trackRight);
  }
  
  // 2. Map the slider position to a useful value range (e.g., 0 to 100)
  sliderValue = map(sliderX, trackLeft, trackRight, 0, 300);
  
  // 3. Draw the track
  stroke(180);
  strokeWeight(4);
  line(trackLeft, sliderY, trackRight, sliderY);
  
  // 4. Draw the handle
  if (isDragging) {
    fill(100, 150, 250); // Change color when active
  } else {
    fill(150);
  }
  noStroke();
  ellipse(sliderX, sliderY, handleSize, handleSize);
  
  // 5. Display the value
  fill(255);
  textSize(16);
  textAlign(CENTER);
  text("Value: " + int(sliderValue), width/2, sliderY + 50);
}

void mousePressed() {
  if (buttonOver) {
     OscMessage sonarMessage = new OscMessage("/sonar");
     
     sonarMessage.add(sonarAngle);
     sonarMessage.add(sonarDistance);
     
     oscP5.send(sonarMessage, myRemoteLocation); // Send it!
     System.out.println("sent message:");
     sonarMessage.print();
     
     if (sliderValue != 0) {
       OscMessage sliderMessage = new OscMessage("/instrumentSlider");
       float normalizedValue = sliderValue / 100;
       sliderMessage.add(normalizedValue);
       
       oscP5.send(sliderMessage, myRemoteLocation); // Send it!
       System.out.println("sent message:");
       sliderMessage.print();
     }
  }
  if (sliderOver) {
     isDragging = true; 
  }
}

void updateMouse(int x, int y) {
  if ( overButton(x, y, buttonSize) ) {
    buttonOver = true;
  } else {
    buttonOver = false;
  }
  if (overSlider(x, y)) {
     sliderOver = true; 
  } else {
    sliderOver = false;
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

boolean overSlider(int x, int y) {
   float d = dist(x, y, sliderX, sliderY);
  if (d < handleSize) {
    return true;
  } 
  return false;
}

void mouseReleased() {
  // Stop dragging when the mouse is released
  isDragging = false;
}
