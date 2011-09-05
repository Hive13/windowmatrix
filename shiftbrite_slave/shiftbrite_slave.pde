// =============================================================================
// shiftbrite_slave: Given an Arduino with a Shiftbrite Shield powering a string
// of Shiftbrites, this firmware turns it into a simple slave that can be
// controlled from a PC.
// 
// It is based off of Rainbow_Plasma.pde from the existing code in the repo.
// =============================================================================

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

// =============================================================================
// Function prototypes
// =============================================================================
void SetPixel(int x, int y, int r, int g, int b);
void WriteLEDArray();

// =============================================================================
// Arduino entry points
// =============================================================================
void setup() {
  Serial.begin(9600);
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

  // Initialize the screen
  for(int x = 0; x < screenWidth; ++x) {
    for(int y = 0; y < screenHeight; ++y) {
      int r = x * 255 / screenWidth;
      int g = y * 255 / screenHeight;
      int b = 0;
      SetPixel(x, y, r, g, b);
    }
  }
}

void loop() {
  // Twiddle the onboard LED state
  if (boardLEDstate ^= 1) digitalWrite(13, HIGH);
  else digitalWrite(13, LOW);
  
  // Compute a frame
  for(int x = 0; x < screenWidth; ++x) {
    for(int y = 0; y < screenHeight; ++y) {
      int r = (x * 255 / screenWidth + frame >> 2) & 0xFF;
      int g = (y * 255 / screenHeight + frame >> 3) & 0xFF;
      int b = (frame >> 4) & 0xFF;
      SetPixel(x, y, r, g, b);
    }
  }
  
  // Actually send that frame
  WriteLEDArray();

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
// General graphics functionality
// =============================================================================
void SetPixel(int x, int y, int r, int g, int b)
{
  LEDArray[x][y][0] = r;
  LEDArray[x][y][1] = g;
  LEDArray[x][y][2] = b;
}

