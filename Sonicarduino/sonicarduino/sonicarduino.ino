#include <Servo.h>

#define trigPin 8
#define echoPin 9
#define servoPin 11

Servo myservo;

// --- INDEPENDENT TIMERS (The Anti-Hallucination Engine) ---
unsigned long previousServoTime = 0;
unsigned long previousPingTime = 0;

int servoDelay = 30;         
const int pingInterval = 60; 

// --- SYSTEM STATE ---
int currentAngle = 15;  
int angleDirection = 1; 


void setup() {
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  
  myservo.attach(servoPin);
  myservo.write(currentAngle);
  
  Serial.begin(9600);
  Serial.setTimeout(10); 
}

void loop() {
  unsigned long currentMillis = millis();

  // 1. READ INCOMING UI COMMANDS (Non-blocking check)
  if (Serial.available() > 0) {
    char commandType = Serial.read();
    
    if (commandType == 'S') {
      int targetDelay = Serial.parseInt();
      if (targetDelay >= 10 && targetDelay <= 150) {
        servoDelay = targetDelay; 
      }
    } 
  }

  // 2. THE SERVO MOVEMENT TIMER
  if (currentMillis - previousServoTime >= servoDelay) {
    previousServoTime = currentMillis;

    currentAngle += angleDirection;

    if (currentAngle >= 165) {
      currentAngle = 165;
      angleDirection = -1;
    } else if (currentAngle <= 15) {
      currentAngle = 15;
      angleDirection = 1;
    }

    myservo.write(currentAngle);
  }

  // 3. THE ULTRASONIC SENSOR TIMER
  if (currentMillis - previousPingTime >= pingInterval) {
    previousPingTime = currentMillis;

    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    // Timeout of 20,000us (Approx 3.4 meters). Prevents hang on missed pings.
    long duration = pulseIn(echoPin, HIGH, 20000); 

    int distance = (duration == 0) ? 999 : (duration * 0.034 / 2);

    // 4. SEND CLEAN DATA TO PROCESSING (Original format restored)
    Serial.print(currentAngle);
    Serial.print(",");
    Serial.print(distance);
    Serial.print("."); 
  }
}