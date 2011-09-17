import processing.serial.*;
// =============================================================================
// Right now this just sends some Perlin noise to the display.
// (1) I need to figure out why its buffering is weird.
// (2) I need to get consistent performance with getting the ACK
// reply after a frame is sent.

Serial serialPort;
int displayWidth;
int displayHeight;
float t;
PImage display;
int scaleFactor;
PFont font;
int offset;


void setup() {

  displayWidth = 7;
  displayHeight = 8;
  scaleFactor = 15;
  offset = 0;
  size(displayWidth*scaleFactor, displayHeight*scaleFactor);
  t = 0;
  try {
    serialPort = initSerial("/dev/ttyUSB0", 9600);
    serialPort.buffer(1);
  } catch(Exception e) {
    print("Error opening serial port: " + e.toString());
  }
  print("Successfully opened serial port!");
  // We turn off framerate and manage our own delays currently.
  //frameRate(30);
  
  display = createImage(displayWidth, displayHeight, RGB);
  font = loadFont("Monospaced.plain-8.vlw");
  textFont(font);
}

void draw() {

  boolean mirrorImage = false;
  boolean mirrorMask = true;
  byte[][] textMask = {
    {1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  };
  byte[][] textMask2 = {
    {1, 0},
    {1, 0},
    {1, 0},
    {1, 0},
    {1, 0},
    {1, 0},
    {1, 0},
    {1, 0},
  };
  /*  
  display.loadPixels();
  for(int y = 0; y < displayHeight; ++y) {
    for(int x = 0; x < displayWidth; ++x) {
      int linear = (displayWidth*y + x);
      int r = 255*int(noise(x/1.0, y/1.2, t/2.0) + 0.5);
      int g = 255*int(noise(x/1.3, y/1.4, t/3.0) + 0.5);
      int b = 255*int(noise(x/1.9, y/1.7, t/4.0) + 0.5);
      display.pixels[linear] = color(r,g,b);
    }
  }
  */
  
  /*String s = "Hive13";
  text(s, 0, 0);*/
  
  //display.updatePixels();
  
  display.loadPixels();
  int lim = textMask[0].length;
  for(int y = 0; y < displayHeight; ++y) {
    for(int x = 0; x < displayWidth; ++x) {
      int xEff = mirrorImage ? x : displayWidth - x - 1;
      int linear = (displayWidth*y + xEff);
      // offset is in [0, lim-1]
      int maskX = mirrorMask ? lim - x - 1 : x;
      maskX = (maskX + offset) % lim;
      int val = 255 * textMask[y][maskX];
      //int val = 100;
      display.pixels[linear] = color(val);
    }
  }
  display.updatePixels();
  
  // Display the image ('display') to the screen
  image(display, 0, 0, displayWidth*scaleFactor, displayHeight*scaleFactor);
  // Push it to the LED display too
  //tryClear();
  //testFrame();
  while (serialPort.available() > 0) {
    delay(50);
    byte[] msg = serialPort.readBytes();
    System.out.printf("Incoming before a command? %s\n", new String(msg));
    System.out.printf("flushing buffer...\n");
  }
  pushFrame(display);
  delay(200);
  //print("Test");
  while (serialPort.available() > 0) {
    delay(50);
    byte[] msg = serialPort.readBytes();
    System.out.printf("Incoming: %s\n", new String(msg));
    System.out.printf("flushing buffer...\n");
  }
  t += 1;
  offset = (offset + 1) % lim;
}

void tryClear() {
  
  delay(1000);
  String test = "cDe";
  byte[] test_bytes = test.getBytes();
  try {
    print("Sending...");
    serialPort.output.write(test_bytes);
  } catch(IOException e) {
    print("Error writing to serial port: " + e.toString());
  }
}

void testFrame() {
  final int elements = displayWidth*displayHeight*3;
  // +3 for: start command block, command, and end command block
  byte cmd[] = new byte[elements + 3];
  cmd[0] = 0x63; // CMD_BLOCK_START
  cmd[1] = 0x46; // CMD_FRAME
  cmd[elements + 2] = 0x65; // CMD_BLOCK_END
  for(int y = 0; y < displayHeight; ++y) {
    for(int x = 0; x < displayWidth; ++x) {
      int linear = (displayWidth*y + x) * 3;
      cmd[linear + 2] = (byte) (255*noise(x/1.0, y/1.2, t/2.0));
      cmd[linear + 3] = (byte) (255*noise(x/1.3, y/1.4, t/3.0));
      cmd[linear + 4] = (byte) (255*noise(x/1.9, y/1.7, t/4.0));
    }
  }
  try {
    serialPort.output.write(cmd);
  } catch(IOException e) {
    print("Error writing to serial port: " + e.toString());
  }
}

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
    serialPort.output.write(cmd);
    System.out.printf("Outgoing (%d bytes), hex: ", cmd.length);
    for(int i = 0; i < cmd.length; ++i) {
      System.out.printf("%x", cmd[i]);
    }
    System.out.printf("\nASCII: %s", new String(cmd));
    System.out.printf("\n");
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


