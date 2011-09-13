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

void setup() {

  displayWidth = 7;
  displayHeight = 8;
  t = 0;
  try {
    serialPort = initSerial("/dev/ttyUSB0", 9600);
    serialPort.buffer(1);
  } catch(Exception e) {
    print("Error opening serial port: " + e.toString());
  }
  print("Successfully opened serial port!");
  //frameRate(30);
}

void draw() {
  //tryClear();
  testFrame();
  //print("Test");
  while (serialPort.available() > 0) {
    byte[] msg = serialPort.readBytes();
    System.out.printf("Data: %s\n", new String(msg));
  }
  t += 1;
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
      int linear = (displayWidth*x + y) * 3;
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


