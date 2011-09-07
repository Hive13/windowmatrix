// =============================================================================
// shiftbrite_slave: Given an Arduino with a Shiftbrite Shield powering a string
// of Shiftbrites, this firmware turns it into a simple slave that can be
// controlled from a PC.
// 
// It is based off of Rainbow_Plasma.pde from the existing code in the repo.
// =============================================================================
// As of now it also has a really rudimentary serial command language.
// cC clears the screen (it's overwritten very quickly though)
// cQ queries for screen size (it will reply with x and y)
// (First byte is BLOCK_START, which is now "c" - it signifies the start of the
// command. Second byte is the command (see macros starting with CMD_). C and Q
// are the only functioning ones right now.

#include <math.h>
#include <avr/pgmspace.h>

// Parameters specific to your setup
#define screenWidth 7
#define screenHeight 8

// Pins
#define clockpin 13 // CI
#define enablepin 10 // EI
#define latchpin 9 // LI
#define datapin 11 // DI

// Data types
typedef struct
{
  int r;
  int g;
  int b;
} ColorRGB;

// For communicating with ShiftBrite
int SB_CommandMode;
int SB_RedCommand;
int SB_GreenCommand;
int SB_BlueCommand;
#define MAXBRIGHT 1023
#define MAXCURRENTRED    50
#define MAXCURRENTGREEN  50
#define MAXCURRENTBLUE   50

// Board mounted LED state
int boardLEDstate = 1;

// Frame count
int frame = 0;

// The frame that SetPixel writes to, and that we send to the Shiftbrite via
// WriteLEDArray
int LEDArray[screenWidth][screenHeight][3] = {0};

// For our serial command protocol
// ===============================

// c
#define BLOCK_START 0x63

// P
#define CMD_PING    0x50
// Q
#define CMD_QUERY   0x51
// D
#define CMD_DEMO    0x44
// F
#define CMD_FRAME   0x46
// C
#define CMD_CLEAR   0x43

// =============================================================================
// Function prototypes
// =============================================================================
void SetPixel(int x, int y, int r, int g, int b);
void WriteLEDArray();
void checkSerial();

// =============================================================================
// Arduino entry points
// =============================================================================
void setup() {
  // These serial messages probably should be removed once a proper command
  // system is added.
  Serial.begin(9600);
  {
    char buf[100];
    snprintf(buf, 100, "Hello from Arduino with %ix%i LED screen.", screenWidth, screenHeight);
    //Serial.println(buf);
  }

  //_init();

  // Set board LED pin - ledPin
  pinMode(13, OUTPUT);
  
  // Make the random MORE RANDOM!
  randomSeed(analogRead(0));
  
  pinMode(datapin, OUTPUT);
  pinMode(latchpin, OUTPUT);
  pinMode(enablepin, OUTPUT);
  pinMode(clockpin, OUTPUT);
  SPCR = (1<<SPE)|(1<<MSTR)|(0<<SPR1)|(0<<SPR0);
  digitalWrite(latchpin, LOW);
  digitalWrite(enablepin, LOW);
   
  SB_CommandMode = B01; // Write to current control registers
  for (int z = 0; z < screenWidth * screenHeight; z++) SB_SendPacket();
  delayMicroseconds(15);
  digitalWrite(latchpin,HIGH); // Latch data into registers
  delayMicroseconds(15);
  digitalWrite(latchpin,LOW);

  //Serial.println("Shiftbrite initialization done.");

  // Initialize the screen
  for(int x = 0; x < screenWidth; ++x) {
    for(int y = 0; y < screenHeight; ++y) {
      int r = x * 255 / screenWidth;
      int g = y * 255 / screenHeight;
      int b = 0;
      SetPixel(x, y, r, g, b);
    }
  }
  WriteLEDArray();
  
  //Serial.println("Wrote first frame.");
}

void loop() {
  // Twiddle the onboard LED state
  if (boardLEDstate ^= 1) digitalWrite(13, HIGH);
  else digitalWrite(13, LOW);
  
  // Compute a frame
  /*
  for(int x = 0; x < screenWidth; ++x) {
    for(int y = 0; y < screenHeight; ++y) {
      int r = (x * 255 / screenWidth + frame >> 9) & 0xFF;
      int g = (y * 255 / screenHeight + frame >> 10) & 0xFF;
      int b = (frame >> 11) & 0xFF;
      SetPixel(x, y, r, g, b);
    }
  }
  */

  // Shift everything by one column.
  for(int x = screenWidth-1; x > 0; --x) {
    for(int y = 0; y < screenHeight; ++y) {
      LEDArray[x][y][0] = LEDArray[x-1][y][0];
      LEDArray[x][y][1] = LEDArray[x-1][y][1];
      LEDArray[x][y][2] = LEDArray[x-1][y][2];
    }
  }
  
  // Add in a new column with random colors
  for(int y = 0; y < screenHeight; ++y) {
    LEDArray[0][y][0] = random(0,255);
    LEDArray[0][y][1] = random(0,255);
    LEDArray[0][y][2] = random(0,255);
  }
  int d = 250.0 * (sin(frame >> 4) + 1.0);
  /*char buf[100];
  snprintf(buf, 100, "%i", d);
  Serial.println(buf);*/
  delay(d);
  //delay(500);
 
  // Actually send that frame
  WriteLEDArray();
  
  checkSerial();

  // Increment frame number
  ++frame;
}

// =============================================================================
// Shiftbrite functionality
// =============================================================================
void SB_SendPacket() {
  // Set dot correction registers (adjusts current)
  if (SB_CommandMode == B01) {
    SB_RedCommand = MAXCURRENTRED;
    SB_GreenCommand = MAXCURRENTGREEN;
    SB_BlueCommand = MAXCURRENTBLUE;
  }
  
  // Perhaps Chris Davis would like to explain this section?
  SPDR = SB_CommandMode << 6 | SB_BlueCommand>>4;
  while(!(SPSR & (1<<SPIF)));
  SPDR = SB_BlueCommand<<4 | SB_RedCommand>>6;
  while(!(SPSR & (1<<SPIF)));
  SPDR = SB_RedCommand << 2 | SB_GreenCommand>>8;
  while(!(SPSR & (1<<SPIF)));
  SPDR = SB_GreenCommand;
  while(!(SPSR & (1<<SPIF)));
}

void WriteLEDArray() {
  // Write to PWM control registers (color)
  SB_CommandMode = B00;

  // Perhaps Chris Davis would like to explain this section too?
  for (int col = screenWidth - 1; col >=0; col--) {
    if(!(col %2)) {
      for (int row = screenHeight - 1; row >=0; row--) {
        SB_RedCommand = LEDArray[col][row][0];
        SB_GreenCommand = LEDArray[col][row][1];
        SB_BlueCommand = LEDArray[col][row][2];
        SB_SendPacket();
      }
    } else {
      for (int row = 0; row < screenHeight; row++) {
        SB_RedCommand = LEDArray[col][row][0];
        SB_GreenCommand = LEDArray[col][row][1];
        SB_BlueCommand = LEDArray[col][row][2];
        SB_SendPacket();
      }
    }
  }
 
  delayMicroseconds(15);       // tsu = 20ns + n*5ns - this is more than enough
  digitalWrite(latchpin,HIGH); // latch data into registers
  delayMicroseconds(15);
  digitalWrite(latchpin,LOW);
}

// =============================================================================
// Serial communication
// =============================================================================
void checkSerial() {
  byte b;
  long i = 0;

  enum { WAITING, INSIDE_COMMAND } state;
  state = WAITING;
  
  while (Serial.available() > 0) {
    b = Serial.read();
    switch(state) {
    case WAITING:
      if (b == BLOCK_START) {
        state = INSIDE_COMMAND;
      } else {
        // Some sort of error here...
      }
      break;
    case INSIDE_COMMAND:
      switch(b) {
      case CMD_PING:
        Serial.println("Ping");
        break;
      case CMD_DEMO:
        Serial.println("Demo");
        break;
      case CMD_CLEAR:
        Serial.println("Clearing");
        for(int x = 0; x < screenWidth; ++x) {
          for(int y = 0; y < screenHeight; ++y) {
            LEDArray[x][y][0] = 0;
            LEDArray[x][y][1] = 0;
            LEDArray[x][y][2] = 0;
          }
        }
        break;
      case CMD_FRAME:
        Serial.println("Frame...");
        break;
      case CMD_QUERY:
        char buf[100];
        snprintf(buf, 100, "%i %i", screenWidth, screenHeight);
        Serial.print(buf);
        break;
      default:
        Serial.println("Unknown command!");
        break;
      }
      state = WAITING;
      break;
    default:
      break;
    }
    ++i;
  }
  
  if (i) {
    char buf[100];
    snprintf(buf, 100, "Just received %i bytes over serial.", i);
    //Serial.println(buf);
  }
}

// =============================================================================
// General graphics functionality
// =============================================================================
void SetPixel(int x, int y, int r, int g, int b)
{
  LEDArray[x][y][0] = r;
  LEDArray[x][y][1] = g;
  LEDArray[x][y][2] = b;
}

