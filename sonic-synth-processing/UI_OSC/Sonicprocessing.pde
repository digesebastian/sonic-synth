import processing.serial.*; 
import oscP5.*;
import netP5.*;

Serial myPort;
OscP5 oscP5;          // The OscP5 networking object
NetAddress myRemoteLocation; // Where we are sending the OSC messages

// ---- TELEMETRY & DATA ----
int iAngle = 0;
int iDistance = 999;
float[] radarHistory = new float[181]; 
float[] radarAlpha = new float[181]; 

// --- MEDIAN FILTER BUFFER ---
int[] medianBuffer = new int[3];
int medianIndex = 0;

// ---- COLOR PALETTE DEFINITION ----
final int cBg         = #0A0F12; 
final int cGrid       = #131B22; 
final int cRadarLine  = #163529; 
final int cBorder     = #3A4D5A; 
final int cNeonCyan   = #00E5FF; 
final int cAlertRed   = #FF3344; 
final int cTextDim    = #8899A6; 
final int cMenuBg     = #162026; 

// ---- DROPDOWN CONFIGURATIONS ----
String[] parameters = {"Frequency", "Attack", "Sustain", "Release", "Amplitude", "Panning"};
int angleRouteIndex = 0;    
int distRouteIndex = 1; 
boolean angleMenuOpen = false;
boolean distMenuOpen = false;

float dropW = 190;
float dropH = 28;

// ---- HARDCODED LAYOUT CONFIGURATIONS ----
float xLeftCol = 40;
float yAngleDrop = 120;
float yDistDrop  = 240;
float yThreshSliders = 360;

float xRightCol = 500;
float yMaxDistSlider  = 120;
float yServoSpeed     = 220;
float yWaveformSlider = 320;
float sliderW = 300;

// Interactive Variables
float maxDistanceValue = 100.0; // cm 
int servoSpeedDelay = 30;
float waveShapeValue = 0.0;
float lastSentWave   = -1.0; 
int lastSentSpeed   = -1;
boolean bellSwitchActive = false;

float distGapThresh = 5.0;
float angleGapThresh = 4.0;
float detectionTimeThresh = 2.0;

// Slider dragging state tracking
boolean dragMaxDist = false, dragSpeed = false, dragWave = false;
boolean dragDistG = false, dragAngleG = false, dragTimeG = false;

// Bottom Right Frame Elements
float radarCenterX = 620;
float radarCenterY = 530;
float radarRadius  = 160;

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
  
  try {
    // Make sure this matches your Arduino port!
    myPort = new Serial(this, "COM16", 9600); 
    myPort.bufferUntil('.'); 
  } catch (Exception e) {
    println("WARNING: Arduino port not found. Running UI in offline mode.");
  }
  
  for(int i = 0; i <= 180; i++) {
    radarHistory[i] = 999.0;
    radarAlpha[i] = 0; 
  }
  
  // Initialize median buffer
  for(int i = 0; i < 3; i++) {
    medianBuffer[i] = 999;
  }
}

void draw() {
  background(cBg);
  drawBackgroundGrid();
  
  fill(cNeonCyan);
  textSize(18);
  textAlign(LEFT, TOP);
  text("N_Tech Acoustic Radar System", xLeftCol, 35);
  
  // 1. LEFT COLUMN
  drawDropdownSelectionBox(xLeftCol, yAngleDrop, "Angle Mapping", parameters[angleRouteIndex], angleMenuOpen);
  drawDropdownSelectionBox(xLeftCol, yDistDrop, "Distance Mapping", parameters[distRouteIndex], distMenuOpen);
  
  updateAndDrawSlider(xLeftCol, yThreshSliders, distGapThresh, 1.0, 20.0, "Distance Gap Threshold", "cm", dragDistG);
  updateAndDrawSlider(xLeftCol, yThreshSliders + 75, angleGapThresh, 1.0, 15.0, "Angle Gap Threshold", "°", dragAngleG);
  updateAndDrawSlider(xLeftCol, yThreshSliders + 150, detectionTimeThresh, 0.5, 5.0, "Detection Time Threshold", "s", dragTimeG);
  
  // 2. RIGHT COLUMN
  updateAndDrawSlider(xRightCol, yMaxDistSlider, maxDistanceValue, 40.0, 200.0, "Max Range Limit", "cm", dragMaxDist);
  
  int speedPercent = int(map(servoSpeedDelay, 100, 10, 10, 100));
  updateAndDrawSlider(xRightCol, yServoSpeed, speedPercent, 10, 100, "Servo Rotation Speed", "%", dragSpeed);
  updateAndDrawSlider(xRightCol, yWaveformSlider, waveShapeValue, 0.0, 3.0, "Waveform Selection", "", dragWave);
  
  drawBellSwitch();
  
  // 3. BOTTOM RIGHT LAYOUT PANELS
  stroke(cBorder); strokeWeight(1); noFill();
  rect(430, 360, 380, 190); 
  rect(430, 550, 380, 70);  
  rect(810, 360, 250, 260); 
  
  drawRadarOutput();
  drawOscilloscopePreview();
  drawTerminalDataReadouts();
  
  // 4. OVERLAY LAYER
  renderDropdownListOverlays();
}

void serialEvent (Serial myPort) { 
  String data = myPort.readStringUntil('.');
  if (data != null && data.length() > 2) {
    data = data.substring(0, data.length()-1).trim();
    int splitIndex = data.indexOf(","); 
    
    if (splitIndex > 0) {
      try {
        int tempAngle = int(data.substring(0, splitIndex).trim());
        int rawDist = int(data.substring(splitIndex+1).trim());
        
        if(tempAngle >= 0 && tempAngle <= 180 && rawDist > 0 && rawDist < 400) {
          
          // --- 1. OUTLIER REJECTION (MEDIAN FILTER) ---
          medianBuffer[medianIndex] = rawDist;
          medianIndex = (medianIndex + 1) % 3;
          
          int[] sorted = {medianBuffer[0], medianBuffer[1], medianBuffer[2]};
          java.util.Arrays.sort(sorted);
          int filteredDist = sorted[1]; 
          
          // --- 2. APPLY TO UI ---
          iAngle = tempAngle;
          iDistance = filteredDist; 
          
          sendSonarData();
          
          if (radarHistory[iAngle] == 999.0) {
             radarHistory[iAngle] = filteredDist; 
          } else {
             radarHistory[iAngle] = (radarHistory[iAngle] * 0.6) + (filteredDist * 0.4);
          }
          
          // --- 3. JUCE TRIGGER PREP ---
          if (radarHistory[iAngle] <= maxDistanceValue) {
             radarAlpha[iAngle] = 255; // Light up the target point
          }
        }
      } catch (Exception e) {}
    }
  }
}

// send sonar data to JUCE
void sendSonarData() {
     OscMessage sonarMessage = new OscMessage("/sonar");
     
     sonarMessage.add(iAngle);
     sonarMessage.add(iDistance);
     
     oscP5.send(sonarMessage, myRemoteLocation); // Send it!
     System.out.println("sent sonar data to JUCE, angle " + iAngle + " and distance " + iDistance);
}


// ---- UI DRAWING FUNCTIONS ----

void drawBackgroundGrid() {
  stroke(cGrid);
  strokeWeight(1);
  for (int i = 0; i < width; i += 20) line(i, 0, i, height);
  for (int j = 0; j < height; j += 20) line(0, j, width, j);
}

void drawRadarOutput() {
  pushMatrix();
  translate(radarCenterX, radarCenterY);
  
  noFill(); stroke(cRadarLine); strokeWeight(1.5);
  arc(0, 0, radarRadius*2, radarRadius*2, PI, TWO_PI);
  arc(0, 0, radarRadius*1.33, radarRadius*1.33, PI, TWO_PI);
  arc(0, 0, radarRadius*0.66, radarRadius*0.66, PI, TWO_PI);
  
  for (int a = 0; a <= 180; a += 30) {
    line(0, 0, radarRadius * cos(radians(a)), -radarRadius * sin(radians(a)));
  }
  
  for (int a = 0; a <= 180; a++) {
    float d = radarHistory[a];
    float alpha = radarAlpha[a];
    
    // Only draw the target if it is within range AND has not faded away completely
    if (d > 2 && d <= maxDistanceValue && alpha > 0) {
      float r = d * (radarRadius / maxDistanceValue);
      float x = r * cos(radians(a));
      float y = -r * sin(radians(a));
      
      // Draw the connecting line (slightly dimmer than the point)
      stroke(cAlertRed, alpha * 0.5); 
      strokeWeight(2);
      line(0, 0, x, y);
      
      // Draw the solid target blip locked in place
      noStroke();
      fill(cAlertRed, alpha);
      ellipse(x, y, 5, 5); 
      
      // FADE LOGIC: Drain the alpha so it disappears over time, but DO NOT MOVE IT
      radarAlpha[a] -= 2.0; // Increased fade speed slightly for a cleaner look
      
      // Clean up memory completely once it fades to black
      if (radarAlpha[a] <= 0) {
        radarAlpha[a] = 0;
        radarHistory[a] = 999.0;
      }
    }
  }

  stroke(cNeonCyan, 220); 
  strokeWeight(3);
  line(0, 0, radarRadius * cos(radians(iAngle)), -radarRadius * sin(radians(iAngle))); 
  
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
  wavePhase -= map(servoSpeedDelay, 100, 10, 0.04f, 0.18f); 
}

void drawTerminalDataReadouts() {
  float tx = 835;
  fill(cTextDim); textSize(14); textAlign(LEFT, TOP);
  text("Current Angle", tx, 385);
  text("Detected Distance", tx, 465);
  
  fill(cNeonCyan); textSize(24);
  text(iAngle + " °", tx, 405);
  
  if (iDistance <= maxDistanceValue) {
    fill(cAlertRed); 
    text(iDistance + " cm", tx, 485);
  } else { 
    fill(cTextDim); 
    text("Scanning...", tx, 485); 
  }
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
  
  fill(255);        textAlign(LEFT, CENTER);  textSize(13);
  text(value, x + 12, y + dropH/2);
}

void updateAndDrawSlider(float x, float y, float currentVal, float minVal, float maxVal, String label, String unit, boolean isDragging) {
  if (isDragging) {
    float handleX = constrain(mouseX, x, x + sliderW);
    float rawValue = map(handleX, x, x + sliderW, minVal, maxVal);
    
    if (label.equals("Waveform Selection")) {
      waveShapeValue = round(rawValue * 10.0f) / 10.0f;
      if (waveShapeValue != lastSentWave && myPort != null) { myPort.write("W" + waveShapeValue + "\n"); lastSentWave = waveShapeValue; }
    } else if (label.equals("Servo Rotation Speed")) {
      servoSpeedDelay = int(map(round(rawValue), 10, 100, 100, 10));
      if (servoSpeedDelay != lastSentSpeed && myPort != null) { myPort.write("S" + servoSpeedDelay + "\n"); lastSentSpeed = servoSpeedDelay; }
    } else if (label.equals("Max Range Limit")) { maxDistanceValue = rawValue; }
    else if (label.equals("Distance Gap Threshold")) { distGapThresh = rawValue; }
    else if (label.equals("Angle Gap Threshold")) { angleGapThresh = rawValue; }
    else if (label.equals("Detection Time Threshold")) { detectionTimeThresh = rawValue; }
  }
  
  float mappedX = 0;
  if (label.equals("Waveform Selection")) mappedX = map(waveShapeValue, minVal, maxVal, x, x + sliderW);
  else if (label.equals("Servo Rotation Speed")) mappedX = map(int(map(servoSpeedDelay, 100, 10, 10, 100)), minVal, maxVal, x, x + sliderW);
  else if (label.equals("Max Range Limit")) mappedX = map(maxDistanceValue, minVal, maxVal, x, x + sliderW);
  else if (label.equals("Distance Gap Threshold")) mappedX = map(distGapThresh, minVal, maxVal, x, x + sliderW);
  else if (label.equals("Angle Gap Threshold")) mappedX = map(angleGapThresh, minVal, maxVal, x, x + sliderW);
  else if (label.equals("Detection Time Threshold")) mappedX = map(detectionTimeThresh, minVal, maxVal, x, x + sliderW);

  fill(cTextDim); textSize(13); textAlign(LEFT, BOTTOM);
  text(label, x, y - 6);
  
  stroke(cBorder); strokeWeight(2);
  line(x, y, x + sliderW, y);
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

// ---- MOUSE INTERACTION ----
void mousePressed() {
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yMaxDistSlider - 10 && mouseY <= yMaxDistSlider + 10) dragMaxDist = true;
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yServoSpeed - 10 && mouseY <= yServoSpeed + 10) dragSpeed = true;
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yWaveformSlider - 10 && mouseY <= yWaveformSlider + 10) dragWave = true;
  
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= yThreshSliders - 10 && mouseY <= yThreshSliders + 10) dragDistG = true;
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= yThreshSliders + 65 && mouseY <= yThreshSliders + 85) dragAngleG = true;
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= yThreshSliders + 140 && mouseY <= yThreshSliders + 160) dragTimeG = true;

  float switchX = xRightCol + sliderW + 20; float switchY = yWaveformSlider - 10;
  if (mouseX >= switchX && mouseX <= switchX + 80 && mouseY >= switchY && mouseY <= switchY + 24) {
    bellSwitchActive = !bellSwitchActive;
    return;
  }

  if (angleMenuOpen) {
    for (int i = 0; i < parameters.length; i++) {
      float itemY = yAngleDrop + dropH + (i * dropH);
      if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) {
        angleRouteIndex = i; angleMenuOpen = false;
        if (myPort != null) myPort.write("A" + angleRouteIndex + "\n"); return;
      }
    }
    angleMenuOpen = false; return;
  }
  
  if (distMenuOpen) {
    for (int i = 0; i < parameters.length; i++) {
      float itemY = yDistDrop + dropH + (i * dropH);
      if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) {
        distRouteIndex = i; distMenuOpen = false;
        if (myPort != null) myPort.write("D" + distRouteIndex + "\n"); return;
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
