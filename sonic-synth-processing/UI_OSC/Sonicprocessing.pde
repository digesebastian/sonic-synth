import processing.serial.*; 
import oscP5.*;
import netP5.*;

Serial myPort;
OscP5 oscP5;          
NetAddress myRemoteLocation; 

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

// ---- DYNAMIC DROPDOWN CONFIGURATIONS ----
String[] synthParams = {"Freq", "Sustain", "Release", "Amplitude"};
String[] bellParams  = {"Freq", "mRatio", "mLevel", "Release", "detune"};
String[] soundOptions = {"Synth Sound", "Bell Sound"};

int angleRouteIndex = 0;    
int distRouteIndex = 1; 
int soundRouteIndex = 0; 

boolean angleMenuOpen = false;
boolean distMenuOpen = false;
boolean soundMenuOpen = false;

float dropW = 190;
float dropH = 28;

// ---- SYMMETRICAL LAYOUT CONFIGURATIONS ----
float xLeftCol = 40;
float yAngleDrop    = 100;
float yDistDrop     = 160; 
float ySampleSwitch = 220; 
float ySampleSlider = 280;

float xRightCol = 500;
float yMaxDistSlider  = 100; 
float yServoSpeed     = 160; 
float ySoundDrop      = 220; 
float yDynSlider1     = 280; 
float yDynSlider2     = 340; 
float sliderW = 300;

// Interactive Variables
float maxDistanceValue = 100.0; // cm 
int servoSpeedDelay = 30;

float waveShapeValue = 0.0;
float reverbMixValue = 50.0;
float reverbDecayValue = 5.0;

boolean sampleThreshActive = false;
int detectionSampleThresh = 15; 

// ---- OSC STATE TRACKING (MEMORY) ----
int lastSentSpeed   = -1;
float lastSentWave   = -1.0; 
int lastSentSoundRoute = -1;
int lastSentAngleIndex = -1; // Changed to int
int lastSentDistIndex = -1;  // Changed to int
float lastSentMaxDist = -1.0; // Added tracker
int lastSentSampleSwitch = -1;
int lastSentSampleThresh = -1;
float lastSentReverbMix = -1.0;
float lastSentReverbDecay = -1.0;

boolean dragMaxDist = false, dragSpeed = false;
boolean dragDyn1 = false, dragDyn2 = false;
boolean dragSample = false;

float radarCenterX = 425; 
float radarCenterY = 530;
float radarRadius  = 160;

float waveCanvasX = 235;  
float waveCanvasY = 550;
float waveCanvasW = 380;
float waveCanvasH = 65;
float wavePhase   = 0.0;

String[] getCurrentParams() {
  return (soundRouteIndex == 0) ? synthParams : bellParams;
}

void setup() {
  size(1100, 650);
  pixelDensity(displayDensity()); 
  smooth(8);
  
  oscP5 = new OscP5(this, 12000);
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);
  
  try {
    myPort = new Serial(this, "COM16", 9600); 
    myPort.bufferUntil('.'); 
  } catch (Exception e) {
    println("WARNING: Arduino port not found. Running UI in offline mode.");
  }
  
  for(int i = 0; i <= 180; i++) {
    radarHistory[i] = 999.0;
    radarAlpha[i] = 0; 
  }
  
  for(int i = 0; i < 3; i++) {
    medianBuffer[i] = 999;
  }
  
  println("--- INITIALIZING SYSTEM & SENDING DEFAULT STATES ---");
  checkAndSendUIUpdates();
}

void draw() {
  background(cBg);
  drawBackgroundGrid();
  
  fill(cNeonCyan);
  textSize(18);
  textAlign(LEFT, TOP);
  text("N_Tech Acoustic Radar System", xLeftCol, 35);
  
  drawDropdownSelectionBox(xLeftCol, yAngleDrop, "Angle Mapping", getCurrentParams()[angleRouteIndex], angleMenuOpen);
  drawDropdownSelectionBox(xLeftCol, yDistDrop, "Distance Mapping", getCurrentParams()[distRouteIndex], distMenuOpen);
  
  drawSampleSwitch(xLeftCol, ySampleSwitch);
  updateAndDrawSlider(xLeftCol, ySampleSlider, detectionSampleThresh, 10.0, 60.0, "Detection Sample Threshold", "smpls", dragSample);
  
  updateAndDrawSlider(xRightCol, yMaxDistSlider, maxDistanceValue, 40.0, 200.0, "Max Range Limit", "cm", dragMaxDist);
  
  int speedPercent = int(map(servoSpeedDelay, 100, 10, 10, 100));
  updateAndDrawSlider(xRightCol, yServoSpeed, speedPercent, 10, 100, "Servo Rotation Speed", "%", dragSpeed);
  
  drawDropdownSelectionBox(xRightCol, ySoundDrop, "Sound Generator", soundOptions[soundRouteIndex], soundMenuOpen);
  
  if (soundRouteIndex == 0) {
    updateAndDrawSlider(xRightCol, yDynSlider1, waveShapeValue, 0.0, 3.0, "Waveform Selection", "", dragDyn1);
  } else {
    updateAndDrawSlider(xRightCol, yDynSlider1, reverbMixValue, 0.0, 100.0, "Reverb Mix", "%", dragDyn1);
    updateAndDrawSlider(xRightCol, yDynSlider2, reverbDecayValue, 0.0, 10.0, "Reverb Decay", "s", dragDyn2);
  }
  
  stroke(cBorder); strokeWeight(1); noFill();
  rect(235, 360, 380, 190); 
  rect(235, 550, 380, 70);  
  rect(615, 360, 250, 260); 
  
  drawRadarOutput();
  drawOscilloscopePreview();
  drawTerminalDataReadouts();
  
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
        if(tempAngle >= 0 && tempAngle <= 180) {
          iAngle = tempAngle;
          if (rawDist > 0 && rawDist < 400) {
            medianBuffer[medianIndex] = rawDist;
            medianIndex = (medianIndex + 1) % 3;
            int[] sorted = {medianBuffer[0], medianBuffer[1], medianBuffer[2]};
            java.util.Arrays.sort(sorted);
            iDistance = sorted[1]; 
            if (radarHistory[iAngle] == 999.0) radarHistory[iAngle] = iDistance; 
            else radarHistory[iAngle] = (radarHistory[iAngle] * 0.6) + (iDistance * 0.4);
            if (radarHistory[iAngle] <= maxDistanceValue) radarAlpha[iAngle] = 255; 
          } else { iDistance = 999; }
          sendSonarData(); 
        }
      } catch (Exception e) {}
    }
  }
}

void sendSonarData() {
     OscMessage sonarMessage = new OscMessage("/sonar");
     sonarMessage.add(iAngle);
     sonarMessage.add(iDistance);
     oscP5.send(sonarMessage, myRemoteLocation); 
}

void checkAndSendUIUpdates() {
  if (soundRouteIndex != lastSentSoundRoute) {
    OscMessage msg = new OscMessage("/instrument");
    msg.add(soundRouteIndex);
    oscP5.send(msg, myRemoteLocation);
    println("OSC OUT -> /instrument : " + soundRouteIndex);
    lastSentSoundRoute = soundRouteIndex;
  }
  
  if (maxDistanceValue != lastSentMaxDist) {
    OscMessage msg = new OscMessage("/max_dist");
    msg.add(maxDistanceValue);
    oscP5.send(msg, myRemoteLocation);
    println("OSC OUT -> /max_dist : " + maxDistanceValue);
    lastSentMaxDist = maxDistanceValue;
  }
  
  if (angleRouteIndex != lastSentAngleIndex) {
    OscMessage msg = new OscMessage("/mapping/angle");
    msg.add(angleRouteIndex);
    oscP5.send(msg, myRemoteLocation);
    println("OSC OUT -> /mapping/angle : " + angleRouteIndex);
    lastSentAngleIndex = angleRouteIndex;
  }
  
  if (distRouteIndex != lastSentDistIndex) {
    OscMessage msg = new OscMessage("/mapping/distance");
    msg.add(distRouteIndex);
    oscP5.send(msg, myRemoteLocation);
    println("OSC OUT -> /mapping/distance : " + distRouteIndex);
    lastSentDistIndex = distRouteIndex;
  }
  
  int currentSwitch = sampleThreshActive ? 1 : 0;
  if (currentSwitch != lastSentSampleSwitch) {
    OscMessage msg = new OscMessage("/sample_skip/active");
    msg.add(currentSwitch);
    oscP5.send(msg, myRemoteLocation);
    lastSentSampleSwitch = currentSwitch;
  }
  
  if (detectionSampleThresh != lastSentSampleThresh) {
    OscMessage msg = new OscMessage("/sample_skip/count");
    msg.add(detectionSampleThresh);
    oscP5.send(msg, myRemoteLocation);
    lastSentSampleThresh = detectionSampleThresh;
  }
  
  if (waveShapeValue != lastSentWave) {
    OscMessage msg = new OscMessage("/waveform");
    msg.add(waveShapeValue);
    oscP5.send(msg, myRemoteLocation);
    lastSentWave = waveShapeValue;
  }
  
  if (reverbMixValue != lastSentReverbMix) {
    OscMessage msg = new OscMessage("/reverb/mix");
    msg.add(reverbMixValue);
    oscP5.send(msg, myRemoteLocation);
    lastSentReverbMix = reverbMixValue;
  }
  
  if (reverbDecayValue != lastSentReverbDecay) {
    OscMessage msg = new OscMessage("/reverb/decay");
    msg.add(reverbDecayValue);
    oscP5.send(msg, myRemoteLocation);
    lastSentReverbDecay = reverbDecayValue;
  }
}

// Drawing helpers kept for brevity
void drawBackgroundGrid() {
  stroke(cGrid); strokeWeight(1);
  for (int i = 0; i < width; i += 20) line(i, 0, i, height);
  for (int j = 0; j < height; j += 20) line(0, j, width, j);
}

void drawSampleSwitch(float x, float y) {
  float swW = 80; float swH = 24;
  fill(cTextDim); textSize(13); textAlign(LEFT, BOTTOM);
  text("Sample Skipping Toggle", x, y - 6);
  stroke(sampleThreshActive ? cNeonCyan : cBorder);
  fill(sampleThreshActive ? cRadarLine : cBg);
  rect(x, y, swW, swH, 4);
  fill(sampleThreshActive ? cNeonCyan : cTextDim);
  textSize(11); textAlign(CENTER, CENTER);
  text(sampleThreshActive ? "ON" : "OFF", x + swW/2, y + swH/2);
}

void drawRadarOutput() {
  pushMatrix();
  translate(radarCenterX, radarCenterY);
  noFill(); stroke(cRadarLine); strokeWeight(1.5);
  arc(0, 0, radarRadius*2, radarRadius*2, PI, TWO_PI);
  arc(0, 0, radarRadius*1.33, radarRadius*1.33, PI, TWO_PI);
  arc(0, 0, radarRadius*0.66, radarRadius*0.66, PI, TWO_PI);
  for (int a = 0; a <= 180; a += 30) line(0, 0, radarRadius * cos(radians(a)), -radarRadius * sin(radians(a)));
  for (int a = 0; a <= 180; a++) {
    if (radarHistory[a] > 2 && radarHistory[a] <= maxDistanceValue && radarAlpha[a] > 0) {
      float r = radarHistory[a] * (radarRadius / maxDistanceValue);
      float x = r * cos(radians(a)), y = -r * sin(radians(a));
      stroke(cAlertRed, radarAlpha[a] * 0.5); strokeWeight(2); line(0, 0, x, y);
      noStroke(); fill(cAlertRed, radarAlpha[a]); ellipse(x, y, 5, 5); 
      radarAlpha[a] -= 2.0; if (radarAlpha[a] <= 0) { radarAlpha[a] = 0; radarHistory[a] = 999.0; }
    }
  }
  stroke(cNeonCyan, 220); strokeWeight(3);
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
    float p = (normX + wavePhase) % TWO_PI; if (p < 0) p += TWO_PI; 
    float sineWave = sin(p), triWave = (abs(p - PI) / PI) * 2.0f - 1.0f, sawWave = (p / PI) - 1.0f, sqWave = (sineWave >= 0) ? 0.7f : -0.7f;
    float yOffset = 0;
    if (waveShapeValue <= 1.0) yOffset = lerp(sineWave, triWave, waveShapeValue);
    else if (waveShapeValue <= 2.0) yOffset = lerp(triWave, sawWave, waveShapeValue - 1.0f);
    else yOffset = lerp(sawWave, sqWave, waveShapeValue - 2.0f);
    vertex(waveCanvasX + x, (waveCanvasY + waveCanvasH/2) + (constrain(yOffset, -1.0f, 1.0f) * (waveCanvasH/2 - 6)));
  }
  endShape();
  wavePhase -= map(servoSpeedDelay, 100, 10, 0.04f, 0.18f); 
}

void drawTerminalDataReadouts() {
  float tx = 640; 
  fill(cTextDim); textSize(14); textAlign(LEFT, TOP);
  text("Current Angle", tx, 385); text("Detected Distance", tx, 465);
  fill(cNeonCyan); textSize(24);
  text(iAngle + " °", tx, 405);
  if (iDistance <= maxDistanceValue) { fill(cAlertRed); text(iDistance + " cm", tx, 485); } 
  else { fill(cTextDim); text("Scanning...", tx, 485); }
}

void drawDropdownSelectionBox(float x, float y, String label, String value, boolean isOpen) {
  fill(cTextDim); textSize(13); textAlign(LEFT, BOTTOM); text(label, x, y - 6);
  stroke(isOpen ? cNeonCyan : cBorder); strokeWeight(1); fill(cBg); rect(x, y, dropW, dropH, 2);
  fill(cNeonCyan); textAlign(RIGHT, CENTER); textSize(10); text("▼", x + dropW - 12, y + dropH/2);
  fill(255); textAlign(LEFT, CENTER); textSize(13); text(value, x + 12, y + dropH/2);
}

void updateAndDrawSlider(float x, float y, float currentVal, float minVal, float maxVal, String label, String unit, boolean isDragging) {
  if (isDragging) {
    float handleX = constrain(mouseX, x, x + sliderW);
    float rawValue = map(handleX, x, x + sliderW, minVal, maxVal);
    if (label.equals("Waveform Selection")) waveShapeValue = round(rawValue * 10.0f) / 10.0f;
    else if (label.equals("Reverb Mix")) reverbMixValue = round(rawValue);
    else if (label.equals("Reverb Decay")) reverbDecayValue = round(rawValue * 10.0f) / 10.0f;
    else if (label.equals("Servo Rotation Speed")) {
      servoSpeedDelay = int(map(round(rawValue), 10, 100, 100, 10));
      if (servoSpeedDelay != lastSentSpeed && myPort != null) { myPort.write("S" + servoSpeedDelay + "\n"); lastSentSpeed = servoSpeedDelay; }
    } else if (label.equals("Max Range Limit")) maxDistanceValue = rawValue;
    else if (label.equals("Detection Sample Threshold")) detectionSampleThresh = round(rawValue);
    checkAndSendUIUpdates();
  }
  float mappedX = map(currentVal, minVal, maxVal, x, x + sliderW);
  fill(cTextDim); textSize(13); textAlign(LEFT, BOTTOM);
  String valStr = (label.equals("Detection Sample Threshold") || label.equals("Reverb Mix") || label.equals("Servo Rotation Speed")) ? str(int(currentVal)) : nf(currentVal, 0, 1);
  text(label + "  [ " + valStr + (unit.equals("") ? "" : " " + unit) + " ]", x, y - 6);
  stroke(cBorder); strokeWeight(2); line(x, y, x + sliderW, y);
  stroke((label.equals("Detection Sample Threshold") && !sampleThreshActive) ? cBorder : cNeonCyan);
  line(x, y, mappedX, y);
  noStroke(); fill(cNeonCyan); ellipse(mappedX, y, 12, 12);
}

void renderDropdownListOverlays() {
  if (angleMenuOpen) drawExpandedOptionsList(xLeftCol, yAngleDrop, getCurrentParams());
  if (distMenuOpen) drawExpandedOptionsList(xLeftCol, yDistDrop, getCurrentParams());
  if (soundMenuOpen) drawExpandedOptionsList(xRightCol, ySoundDrop, soundOptions);
}

void drawExpandedOptionsList(float x, float y, String[] optionsList) {
  pushMatrix();
  for (int i = 0; i < optionsList.length; i++) {
    float itemY = y + dropH + (i * dropH);
    if (mouseX >= x && mouseX <= x + dropW && mouseY >= itemY && mouseY <= itemY + dropH) { fill(cRadarLine); stroke(cNeonCyan); } 
    else { fill(cMenuBg); stroke(cBorder); }
    rect(x, itemY, dropW, dropH);
    fill(255); textSize(12); textAlign(LEFT, CENTER); text(optionsList[i], x + 12, itemY + dropH/2);
  }
  popMatrix();
}

void mousePressed() {
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yMaxDistSlider - 10 && mouseY <= yMaxDistSlider + 10) dragMaxDist = true;
  if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yServoSpeed - 10 && mouseY <= yServoSpeed + 10) dragSpeed = true;
  if (soundRouteIndex == 0) {
    if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yDynSlider1 - 10 && mouseY <= yDynSlider1 + 10) dragDyn1 = true;
  } else {
    if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yDynSlider1 - 10 && mouseY <= yDynSlider1 + 10) dragDyn1 = true;
    if (mouseX >= xRightCol && mouseX <= xRightCol + sliderW && mouseY >= yDynSlider2 - 10 && mouseY <= yDynSlider2 + 10) dragDyn2 = true;
  }
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + sliderW && mouseY >= ySampleSlider - 10 && mouseY <= ySampleSlider + 10) dragSample = true;
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + 80 && mouseY >= ySampleSwitch && mouseY <= ySampleSwitch + 24) { sampleThreshActive = !sampleThreshActive; checkAndSendUIUpdates(); return; }
  if (soundMenuOpen) {
    for (int i = 0; i < soundOptions.length; i++) {
      float itemY = ySoundDrop + dropH + (i * dropH);
      if (mouseX >= xRightCol && mouseX <= xRightCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) {
        soundRouteIndex = i; soundMenuOpen = false; if (angleRouteIndex >= getCurrentParams().length) angleRouteIndex = 0; if (distRouteIndex >= getCurrentParams().length) distRouteIndex = 0; checkAndSendUIUpdates(); return;
      }
    }
    soundMenuOpen = false; return;
  }
  if (angleMenuOpen) {
    String[] currentP = getCurrentParams();
    for (int i = 0; i < currentP.length; i++) {
      float itemY = yAngleDrop + dropH + (i * dropH);
      if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) { angleRouteIndex = i; angleMenuOpen = false; checkAndSendUIUpdates(); return; }
    }
    angleMenuOpen = false; return;
  }
  if (distMenuOpen) {
    String[] currentP = getCurrentParams();
    for (int i = 0; i < currentP.length; i++) {
      float itemY = yDistDrop + dropH + (i * dropH);
      if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= itemY && mouseY <= itemY + dropH) { distRouteIndex = i; distMenuOpen = false; checkAndSendUIUpdates(); return; }
    }
    distMenuOpen = false; return;
  }
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= yAngleDrop && mouseY <= yAngleDrop + dropH) { angleMenuOpen = true; distMenuOpen = false; soundMenuOpen = false; return; }
  if (mouseX >= xLeftCol && mouseX <= xLeftCol + dropW && mouseY >= yDistDrop && mouseY <= yDistDrop + dropH) { distMenuOpen = true; angleMenuOpen = false; soundMenuOpen = false; return; }
  if (mouseX >= xRightCol && mouseX <= xRightCol + dropW && mouseY >= ySoundDrop && mouseY <= ySoundDrop + dropH) { soundMenuOpen = true; angleMenuOpen = false; distMenuOpen = false; return; }
}

void mouseReleased() {
  dragMaxDist = false; dragSpeed = false; dragDyn1 = false; dragDyn2 = false; dragSample = false; 
}
