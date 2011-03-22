// Modified from:
// - 2009 Kenneth Finnegan
// - kennethfinnegan.blogspot.com

// Pins. 
#define clockpin 13 // CI
#define enablepin 10 // EI
#define latchpin 9 // LI
#define datapin 11 // DI

// Can't be higher than 255
#define MAXBRIGHT 1023
#define NumLEDs 48
#define FADENUM 4

// Not sure how well this will work.
// Mainly because I am not sure how the compiler
// will handle huge numbers.
#define ARRAY_MASK 72057594037927935 // 2^56 - 1
#define ROW1_MASK 71494644084506624 // 2^56-2^49
#define ROW2_MASK 558551906910208 // 2^49-2^42
#define ROW3_MASK 4363686772736 // 2^42-2^35
#define ROW4_MASK 34091302912 // 2^35-2^28
#define ROW5_MASK 266338304 // 2^28-2^21
#define ROW6_MASK 2080768 // 2^21-2^14
#define ROW7_MASK 16256 // 2^14-2^7
#define ROW8_MASK 127 // 2^7-1

// s[tate] t[arget] colors
int s[NumLEDs][3] = {0}, t[NumLEDs][3] = {0};

int LEDChannels[NumLEDs][3] = {0};
int SB_CommandMode;
int SB_RedCommand;
int SB_GreenCommand;
int SB_BlueCommand;
 
void setup() {

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
   for (int z = 0; z < NumLEDs; z++) SB_SendPacket();
   delayMicroseconds(15);
   digitalWrite(latchpin,HIGH); // latch data into registers
   delayMicroseconds(15);
   digitalWrite(latchpin,LOW);
}

 
void SB_SendPacket() {
 
    if (SB_CommandMode == B01) {
     SB_RedCommand = 90;
     SB_GreenCommand = 75;
     SB_BlueCommand = 75;
    }
 
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
 
    SB_CommandMode = B00; // Write to PWM control registers
    for (int h = 0;h<NumLEDs;h++) {
	  SB_RedCommand = LEDChannels[h][0];
	  SB_GreenCommand = LEDChannels[h][1];
	  SB_BlueCommand = LEDChannels[h][2];
	  SB_SendPacket();
    }
 
    delayMicroseconds(15);
    digitalWrite(latchpin,HIGH); // latch data into registers
    delayMicroseconds(15);
    digitalWrite(latchpin,LOW);

/* 
    SB_CommandMode = B01; // Write to current control registers
    for (int z = 0; z < NumLEDs; z++) SB_SendPacket();
    delayMicroseconds(15);
    digitalWrite(latchpin,HIGH); // latch data into registers
    delayMicroseconds(15);
    digitalWrite(latchpin,LOW);
 */
}


void loop() {
  int i,j, offset;

  for (j = 0; j < NumLEDs; j++) {

    // check if this LED got to target - shift if not
    if(s[j][0]!=t[j][0] || s[j][1]!=t[j][1] || s[j][2] != t[j][2]) {
      for (i = 0; i<3; i++) {
        if (s[j][i] > t[j][i]) {
          s[j][i] = s[j][i] - 1;
        } else if (s[j][i] < t[j][i]) {
          s[j][i] = s[j][i] + 1;
        }
      }
      
    } else {

      // Select the next target color
      // Start from a random one of the three colors to prevent
      // the cycle from being red biased.
      offset = random(3);
      t[j][offset] = random(MAXBRIGHT);
      t[j][(offset+1)%3] = random(MAXBRIGHT - t[j][offset]);
      t[j][(offset+2)%3] = MAXBRIGHT - t[j][offset] - t[j][(offset+1)%3];
    }

    LEDChannels[j][0] = s[j][0];
    LEDChannels[j][1] = s[j][1];
    LEDChannels[j][2] = s[j][2];
  }
  
  WriteLEDArray();  
  //delay(1);


  // Let the viewer enjoy the new color before
  // selecting the next target color.
  //delay(500);
}
