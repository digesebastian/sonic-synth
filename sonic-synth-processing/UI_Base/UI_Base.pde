import processing.serial.*; 
import oscP5.*;
import netP5.*;

Serial myPort;
OscP5 oscP5;          // The OscP5 networking object
NetAddress myRemoteLocation; // Where we are sending the OSC messages

// Telemetry variables
String angle="";
String distance="";
String data="";
float pixsDistance;
int iAngle, iDistance;
int index1=0;

// Tracking array for continuous object lines
int[] radarHistory = new int[181];

// ---- COLOR PALETTE DEFINITION ----
int cBg         = #0A0F12; // Deep space black
int cGrid       = #131B22; // Blueprint grid line color
int cRadarLine  = #163529; // *** FIXED: Added missing radar line tracking color ***
int cBorder     = #3A4D5A; // Wireframe container boundaries
int cNeonCyan   = #00E5FF; // Main glowing interface color
int cAlertRed    = #FF3344; // Target locked path crimson
int cTextDim     = #8899A6; // Soft labeling text
int cMenuBg      = #162026; // Dropdown list box fill

// ---- DROPDOWN CONFIGURATIONS ----
String[] parameters = {"Frequency", "Attack", "Sustain", "Release", "Amplitude", "Panning"};
int angleRouteIndex = 0;    
int distRouteIndex = 1; // Default to Attack from your image
boolean angleMenuOpen = false;
boolean distMenuOpen = false;

float dropW = 190;
float dropH = 28;

// ---- HARDCODED LAYOUT CONFIGURATIONS (MATCHING YOUR BLUEPRINT) ----
// Left Column
float xLeftCol = 40;
float yAngleDrop = 120;
float yDistDrop  = 240;
float yThreshSliders = 360;

// Right Column (Sliders)
float xRightCol = 500;
float yMaxDistSlider  = 120;
float yServoSpeed     = 220;
float yWaveformSlider = 320;
float sliderW = 300;

// Interactive Variables
float maxDistanceValue = 40.0; // cm
int servoSpeedDelay = 15;
float waveShapeValue = 0.0;
float lastSentWave   = -1.0; 
int lastSentSpeed   = -1;
boolean bellSwitchActive = false;

float distGapThresh = 5.0;
float angleGapThresh = 4.0;
float detectionTimeThresh = 2.0;

// Slider dragging state tracking handles
boolean dragMaxDist = false, dragSpeed = false, dragWave = false;
boolean dragDistG = false, dragAngleG = false, dragTimeG = false;

// Bottom Right Frame Elements
float radarCenterX = 630;
float radarCenterY = 530;
float radarRadius  = 140;

float waveCanvasX = 430;
float waveCanvasY = 550;
float waveCanvasW = 380;
float waveCanvasH = 65;
float wavePhase   = 0.0;

void setup() {
  size(1100, 650);
  smooth(8);
  
  // We start oscP5 listening on port 12000 (standard setup, even if we just send)
  oscP5 = new OscP5(this, 12000);
  
    // Set the destination IP and Port.
  // "127.0.0.1" means "this same computer" (localhost). 
  // 7000 is the port your receiving app (like MaxMSP, TouchDesigner, or Unreal) is listening on.
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);
  
  // Set up Serial communication link on COM6
  myPort = new Serial(this, "COM6", 9600); 
  myPort.bufferUntil('.'); 
  
  for(int i=0; i<=180; i++) {
    radarHistory[i] = 999;
  }
}

void draw() {
  background(cBg);
  drawBackgroundGrid();
  
  // Draw System Identifier Header
  fill(cNeonCyan);
  textSize(18);
  textAlign(LEFT, TOP);
  text("N_Tech Radar System", xLeftCol, 35);
  
  // 1. LEFT COLUMN: Dropdowns & Threshold Sliders
  drawDropdownSelectionBox(xLeftCol, yAngleDrop, "Angle", parameters[angleRouteIndex], angleMenuOpen);
  drawDropdownSelectionBox(xLeftCol, yDistDrop, "Distance", parameters[distRouteIndex], distMenuOpen);
  
  updateAndDrawSlider(xLeftCol, yThreshSliders, distGapThresh, 1.0, 20.0, "Distance Gap Threshold", "cm", dragDistG);
  updateAndDrawSlider(xLeftCol, yThreshSliders + 75, angleGapThresh, 1.0, 15.0, "Angle Gap Threshold", "°", dragAngleG);
  updateAndDrawSlider(xLeftCol, yThreshSliders + 150, detectionTimeThresh, 0.5, 5.0, "Detection Time Threshold", "s", dragTimeG);
  
  // 2. RIGHT COLUMN: Top Parameter Sliders & Bell Switch
  updateAndDrawSlider(xRightCol, yMaxDistSlider, maxDistanceValue, 10.0, 80.0, "Max Distance", "cm", dragMaxDist);
  int speedPercent = int(map(servoSpeedDelay, 50, 5, 10, 100));
  updateAndDrawSlider(xRightCol, yServoSpeed, speedPercent, 10, 100, "Servo Rotation Speed", "%", dragSpeed);
  updateAndDrawSlider(xRightCol, yWaveformSlider, waveShapeValue, 0.0, 3.0, "Waveform / Reverb", "", dragWave);
  
  drawBellSwitch();
  
  // 3. BOTTOM RIGHT LAYOUT CARD CONTAINER PANELS
  stroke(cBorder);
  strokeWeight(1);
  noFill();
  rect(430, 360, 380, 190); // Main radar view viewport container wire frame box
  rect(430, 550, 380, 70);  // Oscilloscope block container boundary
  rect(810, 360, 250, 260); // Sidebar telemetry display terminal area box
  
  drawRadarOutput();
  drawOscilloscopePreview();
  drawTerminalDataReadouts();
  
  // 4. OVERLAY LAYER: Expand dropdown selections on top of everything safely
  renderDropdownListOverlays();
}

void serialEvent (Serial myPort) { 
  data = myPort.readStringUntil('.');
  if (data != null && data.length() > 1) {
    data = data.substring(0, data.length()-1);
    index1 = data.indexOf(","); 
    if (index1 > 0) {
      angle = data.substring(0, index1); 
      distance = data.substring(index1+1, data.length()); 
      try {
        iAngle = int(angle.trim());
        iDistance = int(distance.trim());
        if(iAngle >= 0 && iAngle <= 180) {
          radarHistory[iAngle] = iDistance;
        }
        sendSonarData();
        
      } catch (Exception e) {
        System.out.println("Warning: Error converting input data");
      }
    }
  }
}

void sendSonarData() {
     OscMessage sonarMessage = new OscMessage("/sonar");
     
     sonarMessage.add(iAngle);
     sonarMessage.add(iDistance);
     
     oscP5.send(sonarMessage, myRemoteLocation); // Send it!
     System.out.println("sent sonar data to JUCE, angle " + iAngle + " and distance " + iDistance);
}

// Renders the architectural structural aesthetic background blueprint matrix layout
void drawBackgroundGrid() {
  stroke(cGrid);
  strokeWeight(1);
  for (int i = 0; i < width; i += 20) line(i, 0, i, height);
  for (int j = 0; j < height; j += 20) line(0, j, width, j);
}

void drawDropdownSelectionBox(float x, float y, String label, String value, boolean isOpen) {
  fill(cTextDim);   textSize(13); textAlign(LEFT, BOTTOM);
  text(label, x, y - 6);
  
  stroke(isOpen ? cNeonCyan : cBorder);
  strokeWeight(1);
  fill(cBg);
  rect(x, y, dropW, dropH, 2);
  
  fill(cNeonCyan);  textAlign(RIGHT, CENTER); textSize(10);
  text("▼", x + dropW - 12, y + dropH/2);
  
  fill(255);        textAlign(LEFT, CENTER);   textSize(13);
  text(value, x + 12, y + dropH/2);
}

void updateAndDrawSlider(float x, float y, float currentVal, float minVal, float maxVal, String label, String unit, boolean isDragging) {
  float sliderLength = sliderW;
  if (isDragging) {
    float handleX = constrain(mouseX, x, x + sliderLength);
    float rawValue = map(handleX, x, x + sliderLength, minVal, maxVal);
    
    if (label.equals("Waveform / Reverb")) {
      waveShapeValue = round(rawValue * 10.0f) / 10.0f;
      if (waveShapeValue != lastSentWave) { myPort.write("W" + waveShapeValue + "\n"); lastSentWave = waveShapeValue; }
    } else if (label.equals("Servo Rotation Speed")) {
      int speedPercent = round(rawValue);
      servoSpeedDelay = int(map(speedPercent, 10, 100, 50, 5));
      if (servoSpeedDelay != lastSentSpeed) { myPort.write("S" + servoSpeedDelay + "\n"); lastSentSpeed = servoSpeedDelay; }
    } else if (label.equals("Max Distance")) { maxDistanceValue = rawValue; }
    else if (label.equals("Distance Gap Threshold")) { distGapThresh = rawValue; }
    else if (label.equals("Angle Gap Threshold")) { angleGapThresh = rawValue; }
    else if (label.equals("Detection Time Threshold")) { detectionTimeThresh = rawValue; }
  }
  
  float mappedX = 0;
  if (label.equals("Waveform / Reverb")) mappedX = map(waveShapeValue, minVal, maxVal, x, x + sliderLength);
  else if (label.equals("Servo Rotation Speed")) mappedX = map(int(map(servoSpeedDelay, 50, 5, 10, 100)), minVal, maxVal, x, x + sliderLength);
  else if (label.equals("Max Distance")) mappedX = map(maxDistanceValue, minVal, maxVal, x, x + sliderLength);
  else if (label.equals("Distance Gap Threshold")) mappedX = map(distGapThresh, minVal, maxVal, x, x + sliderLength);
  else if (label.equals("Angle Gap Threshold")) mappedX = map(angleGapThresh, minVal, maxVal, x, x + sliderLength);
  else if (label.equals("Detection Time Threshold")) mappedX = map(detectionTimeThresh, minVal, maxVal, x, x + sliderLength);

  fill(cTextDim); textSize(13); textAlign(LEFT, BOTTOM);
  text(label, x, y - 6);
  
  stroke(cBorder); strokeWeight(2);
  line(x, y, x + sliderLength, y);
  stroke(cNeonCyan);
  line(x, y, mappedX, y);
  
  noStroke(); fill(cNeonCyan);
  ellipse(mappedX, y, 12, 12);
}

void drawBellSwitch() {
  float switchX = xRightCol + sliderW + 20;
  float switchY = yWaveformSlider - 10;
  float swW = 80; float swH = 24;
  
  fill(cTextDim); textSize(13); textAlign(LEFT, BOTTOM);
  text("Bell Switch", switchX, switchY - 6);
  
  stroke(bellSwitchActive ? cNeonCyan : cBorder);
  fill(bellSwitchActive ? cRadarLine : cBg);
  rect(switchX, switchY, swW, swH, 4);
  
  fill(bellSwitchActive ? cNeonCyan : cTextDim);
  textSize(11); textAlign(CENTER, CENTER);
  text(bellSwitchActive ? "ACTIVE" : "OFF", switchX + swW/2, switchY + swH/2);
}

void drawRadarOutput() {
  pushMatrix();
  translate(radarCenterX, radarCenterY);
  noFill(); stroke(cRadarLine); strokeWeight(1);
  
  arc(0, 0, radarRadius*2, radarRadius*2, PI, TWO_PI);
  arc(0, 0, radarRadius*1.33, radarRadius*1.33, PI, TWO_PI);
  arc(0, 0, radarRadius*0.66, radarRadius*0.66, PI, TWO_PI);
  line(-radarRadius, 0, radarRadius, 0);
  line(0, 0, -radarRadius * cos(radians(45)), -radarRadius * sin(radians(45)));
  line(0, 0, -radarRadius * cos(radians(90)), -radarRadius * sin(radians(90)));
  line(0, 0, -radarRadius * cos(radians(135)), -radarRadius * sin(radians(135)));
  
  stroke(cNeonCyan, 120); strokeWeight(1.5);
  line(0, 0, radarRadius * cos(radians(iAngle)), -radarRadius * sin(radians(iAngle))); 
  
  strokeWeight(4); stroke(cAlertRed, 220);
  for (int a = 15; a < 165; a++) {
    int dist1 = radarHistory[a]; int dist2 = radarHistory[a + 1];
    if (dist1 < maxDistanceValue && dist2 < maxDistanceValue && abs(dist1 - dist2) < distGapThresh) {
      float r1 = dist1 * (radarRadius / maxDistanceValue);
      float r2 = dist2 * (radarRadius / maxDistanceValue);
      line(r1 * cos(radians(a)), -r1 * sin(radians(a)), r2 * cos(radians(a + 1)), -r2 * sin(radians(a + 1)));
    }
  }
  popMatrix();
}

void drawOscilloscopePreview() {
  stroke(cRadarLine, 100);
  line(waveCanvasX, waveCanvasY + waveCanvasH/2, waveCanvasX + waveCanvasW, waveCanvasY + waveCanvasH/2);
  stroke(cNeonCyan, 200); strokeWeight(1.5); noFill();
  
  beginShape();
  for (int x = 0; x <= waveCanvasW; x += 2) {
    float normX = map(x, 0, waveCanvasW, 0, TWO_PI * 4);
    float yOffset = 0;
    
    if (waveShapeValue <= 0.5) {
      float t = map(waveShapeValue, 0f, 0.5f, 0f, 1f);
      yOffset = lerp(sin(normX + wavePhase), (abs(((normX + wavePhase) % TWO_PI) - PI) / PI) * 2 - 1, t);
    } else if (waveShapeValue > 0.5 && waveShapeValue <= 1.0) {
      yOffset = (abs(((normX + wavePhase) % TWO_PI) - PI) / PI) * 2 - 1;
    } else if (waveShapeValue > 1.0 && waveShapeValue < 3.0) {
      float t = map(waveShapeValue, 1.0f, 3.0f, 0f, 1f);
      yOffset = lerp((abs(((normX + wavePhase) % TWO_PI) - PI) / PI) * 2 - 1, (((normX + wavePhase) % TWO_PI) / PI) - 1f, t);
    } else if (waveShapeValue == 3.0) {
      yOffset = (sin(normX + wavePhase) >= 0) ? 0.7f : -0.7f;
    }
    
    float py = (waveCanvasY + waveCanvasH/2) + (yOffset * (waveCanvasH/2 - 6));
    vertex(waveCanvasX + x, py);
  }
  endShape();
  wavePhase -= map(servoSpeedDelay, 50, 5, 0.04f, 0.18f);
}

void drawTerminalDataReadouts() {
  float tx = 835;
  fill(cTextDim); textSize(14); textAlign(LEFT, TOP);
  text("Angle", tx, 385);
  text("Distance", tx, 485);
  
  fill(cNeonCyan); textSize(24);
  text(iAngle + " °", tx, 415);
  if (iDistance < maxDistanceValue) text(iDistance + " cm", tx, 515);
  else { fill(cTextDim); text("---", tx, 515); }
}

void renderDropdownListOverlays() {
  if (angleMenuOpen) drawExpandedOptionsList(xLeftCol, yAngleDrop, true);
  if (distMenuOpen)  drawExpandedOptionsList(xLeftCol, yDistDrop, false);
}

void drawExpandedOptionsList(float x, float y, boolean isAngleMenu) {
  pushMatrix();
  for (int i = 0; i < parameters.length; i++) {
    float itemY = y + dropH + (i * dropH);
    if (mouseX >= x && mouseX <= x + dropW && mouseY >= itemY && mouseY <= itemY + dropH) {
      fill(cRadarLine); stroke(cNeonCyan);
    } else {
      fill(cMenuBg); stroke(cBorder);
    }
    rect(x, itemY, dropW, dropH);
    fill(255); textSize(12); textAlign(LEFT, CENTER);
    text(parameters[i], x + 12, itemY + dropH/2);
  }
  popMatrix();
}

void mousePressed() {
  // Slider 1 Drag Hitbox Triggers
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yMaxDistSlider - 10 && mouseY <= yMaxDistSlider + 10) dragMaxDist = true;
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yServoSpeed - 10 && mouseY <= yServoSpeed + 10) dragSpeed = true;
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yWaveformSlider - 10 && mouseY <= yWaveformSlider + 10) dragWave = true;
  
  // Slider 2 Threshold Drag Hitbox Triggers
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= yThreshSliders - 10 && mouseY <= yThreshSliders + 10) dragDistG = true;
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= yThreshSliders + 65 && mouseY <= yThreshSliders + 85) dragAngleG = true;
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= yThreshSliders + 140 && mouseY <= yThreshSliders + 160) dragTimeG = true;

  // Toggle Bell Switch Trigger Box Click Check
  float switchX = xRightCol + sliderW + 20; float switchY = yWaveformSlider - 10;
  if (mouseX >= switchX && mouseX <= switchX + 80 && mouseY >= switchY && mouseY <= switchY + 24) {
    bellSwitchActive = !bellSwitchActive;
    return;
  }

  // Parse Dropdown Expand/Close selection tree routing states
  if (angleMenuOpen) {
    for (int i = 0; i < parameters.length; i++) {
      float itemY = yAngleDrop + dropH + (i * dropH);
      if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) {
        angleRouteIndex = i; angleMenuOpen = false;
        myPort.write("A" + angleRouteIndex + "\n"); return;
      }
    }
    angleMenuOpen = false; return;
  }
  
  if (distMenuOpen) {
    for (int i = 0; i < parameters.length; i++) {
      float itemY = yDistDrop + dropH + (i * dropH);
      if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) {
        distRouteIndex = i; distMenuOpen = false;
        myPort.write("D" + distRouteIndex + "\n"); return;
      }
    }
    distMenuOpen = false; return;
  }

  if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= yAngleDrop && mouseY <= yAngleDrop + dropH) { angleMenuOpen = true; distMenuOpen = false; return; }
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= yDistDrop && mouseY <= yDistDrop + dropH) { distMenuOpen = true; angleMenuOpen = false; return; }
}

void mouseReleased() {
  dragMaxDist = false; dragSpeed = false; dragWave = false;
  dragDistG = false;   dragAngleG = false; dragTimeG = false;
}
