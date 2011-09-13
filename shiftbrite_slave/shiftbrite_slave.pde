// =============================================================================
// shiftbrite_slave: Given an Arduino with a Shiftbrite Shield powering a string
// of Shiftbrites, this firmware turns it into a simple slave that can be
// controlled from a PC.
// 
// It is based off of Rainbow_Plasma.pde from the existing code in the repo.
// =============================================================================
// As of now it also has a rudimentary serial command language. See the
// whole block of CMD_* and REPLY_* constants.
// Commands so far:
// cPe  - Ping (should reply rAe for reply start, ACK, reply end)
// cQe  - Query display size
// cCe  - Clear the display
// cF{rgbrgbrgbrgbrgb..}e  - Send frame. Between the 'F' and the 'e, put
// one scanline at a time with one byte for R, one for G, one for B, and so
// on. If you send less than screenWidth*screenHeight*3 bytes in the body,
// it will block any further command until you do!
// cDe  - Toggle demo modes (clearing and sending a frame override this mode)
//
// A reply starting with rE indicates an error (it will be followed with a
// one-byte error code, which the ERROR_* constants comprise, then the 'e'
// for ending the reply block)
// A reply of rAe indicates an acknowledgement.

// If DEBUG is on, verbose serial messages are printed, which is good
// for diagnosing errors but bad for any programs that expect it to
// speak a normal serial protocol.
// (use the debugMsg(char*) function for this)
#define DEBUG 0

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

// For demo modes mostly: Frame count
int frame = 0;
// SLAVE mode: Only displaying via CMD_FRAME, CMD_CLEAR
// DEMO_BLUE_HORIZ, DEMO_GREEN_VERT: Animating itself with some simple demos
// until interrupted by CMD_FRAME, CMD_CLEAR
enum { SLAVE, DEMO_BLUE_HORIZ, DEMO_GREEN_VERT } mode = DEMO_BLUE_HORIZ;

// The frame that SetPixel writes to, and that we send to the Shiftbrite via
// WriteLEDArray
int LEDArray[screenWidth][screenHeight][3] = {0};

// ===============================
// For our serial command protocol
// ===============================

// Commands we receive
// ===================
// General structure:
// CMD_BLOCK_START
// CMD_*
// arguments
// CMD_BLOCK_END

// c
#define CMD_BLOCK_START 0x63

// P (Ping, just reply ACK)
#define CMD_PING    0x50
// Q (Query, return screen size)
#define CMD_QUERY   0x51
// D (Demo mode - let the display animate itself. Note that CMD_CLEAR and
// CMD_FRAME end this mode.)
#define CMD_DEMO    0x44
// F (Frame, specify frame data)
#define CMD_FRAME   0x46
// C (Clear screen)
#define CMD_CLEAR   0x43

#define CMD_BLOCK_END  0x65


// Our replies back to commands
// ============================
// General structure:
// REPLY_BLOCK_START
// REPLY_*
// arguments
// REPLY_BLOCK_END

// r (start reply block)
#define REPLY_BLOCK_START 0x72
// A (ACK for any command that gives no other output)
#define REPLY_ACK     0x41
// E (Error, followed by error number)
#define REPLY_ERROR   0x45
// e (end reply block)
#define REPLY_BLOCK_END   0x65

// Possible error codes, following REPLY_ERROR
// S (received something else where CMD_BLOCK_START was expected)
#define ERROR_CMD_NO_START  0x53
// U (unknown command)
#define ERROR_CMD_UNKNOWN 0x55
// P (received end block prematurely)
#define ERROR_PREMATURE_END 0x50
// R (received unexpected arguments where CMD_BLOCK_END expected)
#define ERROR_ARG_UNEXPECTED 0x52
// I (internal error, most likely not your fault)
#define ERROR_INTERNAL 0x49


// =============================================================================
// Function prototypes
// =============================================================================
void SetPixel(int x, int y, int r, int g, int b);
void WriteLEDArray();
void checkSerial();
void replyError(byte errorCode);
void replyAck();
void debugMsg(char * msg);

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
  
  // If we're in demo mode, happily animate
  if (mode == DEMO_BLUE_HORIZ) {
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
      int sample = random(0,100);
      LEDArray[0][y][0] = 255 * (sample > 97);
      LEDArray[0][y][1] = 255 * (sample > 97);
      LEDArray[0][y][2] = 127 * (sample > 60) + 127 * (sample > 80);
    }
    delay(200);
  } else if (mode == DEMO_GREEN_VERT) {
    // Shift everything by one column.
    for(int y = screenHeight-1; y > 0; --y) {
      for(int x = 0; x < screenWidth; ++x) {
        LEDArray[x][y][0] = LEDArray[x][y-1][0];
        LEDArray[x][y][1] = LEDArray[x][y-1][1];
        LEDArray[x][y][2] = LEDArray[x][y-1][2];
      }
    }
    
    // Add in a new column with random colors
    for(int x = 0; x < screenWidth; ++x) {
      int sample = random(0,100);
      LEDArray[x][0][0] = 255 * (sample > 97);
      LEDArray[x][0][1] = 127 * (sample > 60) + 127 * (sample > 80);;
      LEDArray[x][0][2] = 255 * (sample > 97);
    }
    delay(200);
  }
 
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
  //Serial.println(" checkSerial ");
  byte b;
  long i = 0;

  // N.B. Next few variables are static because this function is left and
  // entered multiple times in the course of a command.
  // This may not be optimal.

  // IDLE: We are awaiting the start of a command block.
  // WAITING_COMMAND: We're inside a command block, awaiting a command.
  // WAITING_ARGS: We're awaiting arguments to a command.
  // WAITING_END: We have a command; we're awaiting end-of-block.
  // FLUSHING: We're flushing input until the next command block starts, on
  // account of receiving erroneous data.
  static enum { IDLE, WAITING_COMMAND, WAITING_ARGS, WAITING_END, FLUSHING } state;
  //state = IDLE;
  // Set 'command' to the command we received (i.e. one of the CMD_* constants)
  static int command;
  // Offset to hold some additional state when in WAITING_ARGS state
  // (e.g. current position for CMD_FRAME)
  static int offset;
  
  while (Serial.available() > 0) {
    debugMsg(" byte ");
    b = Serial.read();
    switch(state) {
    case FLUSHING:
      command = -1;
      debugMsg(" flushing ");
      if (b != CMD_BLOCK_START) {
        break;
      } else {
        // Fall through to IDLE (no 'break' here)
      }
    case IDLE:
      command = -1;
      offset = 0;
      debugMsg(" idle ");
      if (b == CMD_BLOCK_START) {
        state = WAITING_COMMAND;
      } else {
        replyError(ERROR_CMD_NO_START);
        state = FLUSHING;
      }
      break;
    case WAITING_COMMAND:
      debugMsg(" waiting command ");
      command = b;
      switch(b) {
      // Check that it's a valid command.
      case CMD_PING:
      case CMD_QUERY:
      case CMD_CLEAR:
      case CMD_DEMO:
        // None of these commands take arguments
        state = WAITING_END;
        break;
      case CMD_FRAME:
        mode = SLAVE;
        offset = 0;
        state = WAITING_ARGS;
        break;
      default:
        replyError(ERROR_CMD_UNKNOWN);
        state = FLUSHING;
        break;
      }
      break;
    case WAITING_END:
      debugMsg(" waiting end ");
      if (b != CMD_BLOCK_END) {
        replyError(ERROR_ARG_UNEXPECTED);
        state = FLUSHING;
        break;
      }
      // 'state' is IDLE until set otherwise
      state = IDLE;
      switch(command) {
      case CMD_PING:
        replyAck();
        break;
      case CMD_DEMO:
        // If already in demo mode then toggle between demos;
        // if not then put it in demo mode
        if (mode == DEMO_BLUE_HORIZ) {
          mode = DEMO_GREEN_VERT;
        } else {
          mode = DEMO_BLUE_HORIZ;
        }
        break;
      case CMD_CLEAR:
        mode = SLAVE;
        for(int x = 0; x < screenWidth; ++x) {
          for(int y = 0; y < screenHeight; ++y) {
            LEDArray[x][y][0] = 0;
            LEDArray[x][y][1] = 0;
            LEDArray[x][y][2] = 0;
          }
        }
        replyAck();
        break;
      case CMD_QUERY:
        // TODO: Send this in binary instead. Use the protocol.
        char buf[100];
        snprintf(buf, 100, "%i %i", screenWidth, screenHeight);
        Serial.print(buf);
        break;
      default:
        // This generally is not an error case
        state = FLUSHING;
        break;
      }
      break;
    case WAITING_ARGS:
      debugMsg(" waiting args ");
      switch(command) {
      case CMD_FRAME:
        debugMsg(" in CMD_FRAME ");
        // Avoid, very heavily, overrunning our array!
        if (offset >= (screenWidth*screenHeight*3)) {
          debugMsg(" offset too large ");
          replyError(ERROR_ARG_UNEXPECTED);
          state = FLUSHING;
          break;
        } else if (offset < 0) {
          // WTF?
          debugMsg(" offset < 0? ");
          replyError(ERROR_INTERNAL);
          state = FLUSHING;
          break;
        }
        {
          // Data here is RGBRGBRGBRGB... so we must divide by 3 to
          // find out current offset.
          int offset_xy = offset / 3;
          // comp = component (0=R, 1=G, 2=B)
          int comp = offset % 3;
          // (1) offset_xy can't be negative, and the modulo with screenWidth
          // limits it to [0,screenWidth], so that index should be safe.
          // (2) offset < (screenWidth*screenHeight*3)
          //    => offset_xy < screenWidth*screenHeight
          //    => offset_xy / screenWidth < screenHeight
          // So the second index should be safe.
          // (3) comp is in [0,2] so that index should be safe.
          LEDArray[offset_xy % screenWidth][offset_xy / screenWidth][comp] = b;

          offset += 1;
          if (offset == screenHeight*screenWidth*3) {
            debugMsg(" hit offset end! ");
            state = WAITING_END;
          }
        }
        break;
      default:
        debugMsg(" premature end? ");
        replyError(ERROR_PREMATURE_END);
        state = FLUSHING;
        break;
      }
      debugMsg(" leaving waiting args ");
      break;
    default:
      debugMsg(" unknown state? ");
      // WTF?
      replyError(ERROR_INTERNAL);
      state = FLUSHING;
      break;
    }
    ++i;
  }
  
  /*
  if (i) {
    char buf[100];
    snprintf(buf, 100, "Just received %i bytes over serial.", i);
    //Serial.println(buf);
  }
  */
}

// Send an error reply with the given error code
// errorCode should be one of the ERROR_* constants
void replyError(byte errorCode) {
  Serial.write(REPLY_BLOCK_START);
  Serial.write(REPLY_ERROR);
  Serial.write(errorCode);
  Serial.write(REPLY_BLOCK_END);
}

void replyAck() {
  Serial.write(REPLY_BLOCK_START);
  Serial.write(REPLY_ACK);
  Serial.write(REPLY_BLOCK_END);
}

void debugMsg(char * msg) {
  #if DEBUG
  Serial.println(msg);
  #endif
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

