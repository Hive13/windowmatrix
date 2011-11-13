// This controls an LED display (i.e. the Glass Block LED Display
// at Hive13) via serial commands to the connected Arduino &
// Shiftbrite shield.
// This draws on that display according to messages received over
// OSC. Right now, the messages it receives are the type sent via
// a demo UI called "Multibutton Demo" that is part of Control
// (http://charlie-roberts.com/Control/).

// From my brief reverse-engineering (which is unnecessary since
// the code is available and it's just Javascript):
// The Multibutton UI of Control sends messages with addresses
// like "/multi/7" where 7 is the square number. They're numbered
// left-to-right in rows and then down columns. As it's an 8x8
// display, the square numbers go from 0 to 63.
// It provides one argument as well, an integer value.
// Values of 0 and 127 indicate that, respectively, a square
// just turned on or turned off.

import processing.serial.*;
import oscP5.*;
import netP5.*;

Serial serialPort;
// TODO: Query the Arduino to get this information. The commands
// are already implemented, we're just not making use of them.
int displayWidth = 7;
int displayHeight = 8;

// If true, don't send anything to the LED display:
// (but we continue to show things on Processing's display)
boolean dryRun = false;

// As the display has a very small number of pixels, we must scale
// it up to display it on our screen. This number is the factor
// by which we scale.
int scaleFactor = 30;

// This display is what is pushed via serial to the LED display.
// (Specifically, to the Arduino controlling the Shiftbrites.)
PImage display;

OscP5 oscP5 = null;
// Which port to listen on for OSC messages:
int listenPort = 10000;
// If true, then we should update the LED display.
boolean updateLeds = true;

void setup() {

  size(displayWidth*scaleFactor, displayHeight*scaleFactor);
  if (!dryRun) {
    try {
      serialPort = initSerial("/dev/ttyUSB1", 9600);
      serialPort.buffer(1);
    } catch(Exception e) {
      println("Error opening serial port: " + e.toString());
    }
    println("Successfully opened serial port!");
  } else {
    println("Not using serial port.");
  }
  // We turn off framerate and manage our own delays currently.
  //frameRate(30);
  
  display = createImage(displayWidth, displayHeight, RGB);

  // Init OSC
  oscP5 = new OscP5(this,listenPort);
}

void draw() {

  // Display the image ('display') to the screen
  image(display, 0, 0, displayWidth*scaleFactor, displayHeight*scaleFactor);
  
  delay(10);
  while (!dryRun && serialPort.available() > 0) {
    delay(10);
    byte[] msg = serialPort.readBytes();
    System.out.printf("Incoming before a command? %s\n", new String(msg));
    System.out.printf("flushing buffer...\n");
  }
  
  // If we need to, push the display over serial to the
  // Arduino/Shiftbrite.
  if (updateLeds) {
    println("Display is dirty. Pushing a frame.");
    if (!dryRun) pushFrame(display);
    delay(100);
    
    while (!dryRun && serialPort.available() > 0) {
      delay(10);
      byte[] msg = serialPort.readBytes();
      System.out.printf("Incoming: %d bytes\n", msg.length);
      System.out.printf("flushing buffer...\n");
    }
    updateLeds = false;
  }
}

// Send this PImage to the LED display. Assumes that the
// serial port has already been initialized.
void pushFrame(PImage img) {
  final int elements = displayWidth*displayHeight*3;
  // +3 for: start command block, command, and end command block
  byte cmd[] = new byte[elements + 3];
  cmd[0] = 0x63; // CMD_BLOCK_START
  cmd[1] = 0x46; // CMD_FRAME
  cmd[elements + 2] = 0x65; // CMD_BLOCK_END
  img.loadPixels();
  for(int y = 0; y < displayHeight; ++y) {
    for(int x = 0; x < displayWidth; ++x) {
      int linear = displayWidth*y + x;
      cmd[linear*3 + 2] = (byte) (red(img.pixels[linear]));
      cmd[linear*3 + 3] = (byte) (green(img.pixels[linear]));
      cmd[linear*3 + 4] = (byte) (blue(img.pixels[linear]));
    }
  }
  try {
    // Divide the buffer up a bit so that it does not overrun the buffers
    int chunkSize = 32;
    int offset = 0;
    while (offset < cmd.length) {
      int remaining = cmd.length - offset;
      byte tmp[] = new byte[min(chunkSize, remaining)];
      for(int i = 0; i < chunkSize && i < remaining; ++i) {
        tmp[i] = cmd[offset + i];
      }
      serialPort.output.write(tmp);
      System.out.printf("Outgoing (%d bytes), hex: ", tmp.length);
      for(int i = 0; i < tmp.length; ++i) {
        System.out.printf("%x", tmp[i]);
      }
      System.out.printf("\n");
      offset += chunkSize;
    }
    //System.out.printf("\nASCII: %s", new String(cmd));
  } catch(IOException e) {
    print("Error writing to serial port: " + e.toString());
  }
}

// "name" = name of serial port (e.g. /dev/ttyUSB0). If left blank, the first
// one found will be chosen. 'baud' is baud rate.
Serial initSerial(String name, int baud) throws Exception {
  Serial port = null;
  String serialName = name;
  if (name == null) {
    String[] ports = Serial.list();
    print("Found " + ports.length + " serial ports!\n");
    for(int i = 0; i < ports.length; ++i) {
      print("Serial port " + i + ": " + ports[i] + "\n");
    }
    if (ports.length == 0) {
      throw new Exception("No serial ports found!");
    }
    serialName = ports[0];
  }
  print("Trying serial port " + serialName + "\n");
  
  port = new Serial(this, serialName, baud);
  return port;
}



void oscEvent(OscMessage msg) {
  
  // Get address pattern and check it.
  String addr = msg.addrPattern();
  String baseAddr = "/multi/";
  if (!addr.startsWith(baseAddr)) {
    // println("Ignoring - wrong address pattern");
    return;
  }
  
  // Check that argument signature is what we expect.
  if (!msg.checkTypetag("i")) {
    println("Got unexpected typetag, " + msg.typetag() + "; aborting!");
    return;
  }
  
  // Get the location out of the address pattern.
  // See comments at the top of the file for some insight into
  // what we're doing.
  String suffix = addr.substring(baseAddr.length(), addr.length());
  int locationLinear = -1;
  try {
    locationLinear = Integer.parseInt(suffix);
  } catch (Exception e) {
    println("Error getting suffix from address, " + addr);
    return;
  }
  // This conversion assumes the 8x8 grid that the Multibutton
  // Demo UI uses in Control:
  int x = locationLinear % 8;
  int y = locationLinear / 8;
  
  // Paranoia checks & extracting value from the OSC message
  // (it's just 0 or 127 for off and on, respectively)
  int val = -1;
  // Catch any of oscP5's errors when trying to convert
  try {
    val = msg.get(0).intValue();
  } catch (Exception e) {
    println("Exception thrown: " + e.toString());
    return;
  }
  if (x >= display.width) {
    println("X value (" + x + ") out of bounds!");
    return;
  }
  if (y >= display.height) {
    println("Y value (" + y + ") out of bounds!");
  }

  // Now actually set this value in 'display', and tell the rest
  // of the program to push those changes out.
  display.loadPixels();
  // Linearize it again (we can't rely on the numbering
  // being identical between the PImage and the Multibutton Demo
  // UI, hence the conversion to x,y prior)
  display.pixels[display.width*y + x] = color(val, val, val);
  updateLeds = true;
  display.updatePixels();

}

