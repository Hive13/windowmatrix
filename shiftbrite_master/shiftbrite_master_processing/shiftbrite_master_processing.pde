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
float offset;

// How much the offset is updated at each frame. (Unit is pixels)
float offset_delta;

// If true, don't send anything to the LED display
boolean dryRun;

void setup() {

  displayWidth = 7;
  displayHeight = 8;
  scaleFactor = 15;
  offset = 0.0;
  offset_delta = 0.2;
  dryRun = false;
  size(displayWidth*scaleFactor * 2, displayHeight*scaleFactor * 2);
  t = 0;
  if (!dryRun) {
    try {
      serialPort = initSerial("/dev/ttyUSB0", 9600);
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

/*  
  // Load an image and load it into textMask
  PImage img = loadImage("hive13.png");
  img.loadPixels();
  // We must truncate everything beyond displayHeight
  textMask3 = new byte[displayHeight][img.width];
  for(int y = 0; y < img.height && y < displayHeight; ++y) {
    final int offset = y * img.width;
    for(int x = 0; x < img.width; ++x) {
      textMask3[y][x] = (byte) img.pixels[offset + x];
    }
  }
*/
}

void draw() {

  boolean mirrorImage = false;
  boolean mirrorMask = true;

  scrollingHive13Logo(display);

  // Display the image ('display') to the screen
  image(display, 0, 0, displayWidth*scaleFactor, displayHeight*scaleFactor);
  
  while (!dryRun && serialPort.available() > 0) {
    delay(10);
    byte[] msg = serialPort.readBytes();
    System.out.printf("Incoming before a command? %s\n", new String(msg));
    System.out.printf("flushing buffer...\n");
  }
  if (!dryRun) pushFrame(display);
  delay(60);
  //print("Test");
  while (!dryRun && serialPort.available() > 0) {
    delay(10);
    byte[] msg = serialPort.readBytes();
    //System.out.printf("Incoming: %s\n", new String(msg));
    System.out.printf("Incoming: %d bytes\n", msg.length);
    System.out.printf("flushing buffer...\n");
  }
  t += 1;
  

}

void scrollingHive13Logo(PImage display) {
  // Some old text masks:
  byte[][] textMask = {
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  };
  
  scrollImage(display, textMask, offset, 255, false, true);
  
  offset = (offset + offset_delta) % textMask[0].length;
}

// Scrolls imgMask across 'display', where imgMask is a byte array.
// Indexing is imgMask[y][x] - possibly the reverse of what's expected.
// If it has more elements in y than can fit in the 'display' then it
// will disregard larger y values.
// However, it will be scrolled horizontally for larger x than fits on
// 'display'. 'offset' is a distance in pixels of how far to scroll.
// If it is fractional, interpolation is done.
// 'scaleFactor' will scale the elements of the mask before putting
// them on the display. If your mask is only 0s and 1s, 255 would be
// an appropriate number here.
// mirrorImage and mirrorMask control whether the mask and the motion
// are reversed, respectively.
// FIXME: This should be a separate class. The number of parameters is huge.
void scrollImage(PImage display, byte imgMask[][], float offset, float scaleFactor, boolean mirrorImage, boolean mirrorMask)
{
    
  display.loadPixels();
  int lim = imgMask[0].length;
  for(int y = 0; y < displayHeight; ++y) {
    for(int x = 0; x < displayWidth; ++x) {
      int xEff = mirrorImage ? x : displayWidth - x - 1;
      int linear = (displayWidth*y + xEff);
      // offset is in [0, lim-1]
      float maskX = mirrorMask ? lim - x - 1 : x;
      maskX = (maskX + offset) % lim;
      
      // Get the indices on both sides.
      int maskX1 = floor(maskX);
      int maskX2 = (maskX1 + 1) % lim;
      // f tells how much of each to mix in to interpolate
      float f = maskX - maskX1;
      //print(f);
      //print("\n");
      
      byte mask1 = imgMask[y][maskX1];
      byte mask2 = imgMask[y][maskX2];
      float lerped = lerp(mask1, mask2, f);
      int r = floor(lerped * 255.0);
      int g = floor(lerped * 255.0);
      int b = floor(lerped * 255.0);
      //int val = 100;
      display.pixels[linear] = color(r, g, b);
    }
  }
  display.updatePixels();
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


