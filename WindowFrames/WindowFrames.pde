#include <avr/pgmspace.h>

#define clockpin 13 // CI
#define enablepin 10 // EI
#define latchpin 9 // LI
#define datapin 11 // DI

#define NumLEDs 56

#define rows 8
#define columns 7

int LEDChannels[NumLEDs][3] = {0};
int SB_CommandMode;
int SB_RedCommand;
int SB_GreenCommand;
int SB_BlueCommand;

int current_img[columns][rows][3] = {0};
int next_img[columns][rows][3] = {0};

int num_frames = 2;
int current_frame = 0;

PROGMEM prog_int16_t all_white[columns][rows][3] = { 
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } } 
};

PROGMEM prog_int16_t hive_logo[columns][rows][3] = { 
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , {    0, 1000,    0 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , {    0, 1000,    0 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , {    0, 1000,    0 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , {    0, 1000,    0 } , { 1000, 1000, 1000 } },
    { { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } , { 1000, 1000, 1000 } } 
};


void setup() {

  pinMode(datapin, OUTPUT);
  pinMode(latchpin, OUTPUT);
  pinMode(enablepin, OUTPUT);
  pinMode(clockpin, OUTPUT);
  SPCR = (1<<SPE)|(1<<MSTR)|(0<<SPR1)|(0<<SPR0);
  digitalWrite(latchpin, LOW);
  digitalWrite(enablepin, LOW);

}


void SB_SendPacket() {

  if (SB_CommandMode == B01) {
    SB_RedCommand = 65;
    SB_GreenCommand = 50;
    SB_BlueCommand = 50;
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

  SB_CommandMode = B01; // Write to current control registers
  for (int z = 0; z < NumLEDs; z++) SB_SendPacket();
  delayMicroseconds(15);
  digitalWrite(latchpin,HIGH); // latch data into registers
  delayMicroseconds(15);
  digitalWrite(latchpin,LOW);

}

void ConvertImg(){
  //converts the "2D" current_img array into the "1D" LEDChannels array

  for ( int x = 0; x < columns; x++ ){
    for ( int y = 0; y < rows; y++ ){

      int h = 0;
      //the following deals with the alternating direction of the rows
      if ( x%2 == 0 ){
        h = (rows*x) + y;
      }
      else{
        h = (rows*x) + (rows-y-1);
      }

      LEDChannels[h][0] = current_img[x][y][0];
      LEDChannels[h][1] = current_img[x][y][1];
      LEDChannels[h][2] = current_img[x][y][2];
    }
  }

}

void loop() {

  //do something to modify the next_img
  //this should be a big blinking 'H'
  if ( current_frame%2 == 0 ){
      memcpy_P( next_img , all_white , ( sizeof(next_img) ) );    
  }
  else{
      memcpy_P( next_img , hive_logo , ( sizeof(next_img) ) );
  }

  current_frame++;
  if ( current_frame >= num_frames ) current_frame = 0;

  //no need to alter below this point

  //copy the next_img to the current_img
  memcpy( current_img , next_img , sizeof(current_img) );
  //memcpy( current_img , next_img , ( NumLEDs * 3 * sizeof(int) ) );

  //change the 2D grid of values into a 1D chain of values
  ConvertImg();

  //write out the current array to the "display"
  WriteLEDArray();

  //pause between refresh
  delay(400);

}
