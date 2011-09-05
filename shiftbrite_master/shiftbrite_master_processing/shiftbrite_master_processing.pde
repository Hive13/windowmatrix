import processing.serial.*;
// =============================================================================
Serial serialPort;

void setup() {

  try {
    serialPort = initSerial("/dev/ttyUSB0", 9600);
  } catch(Exception e) {
    print("Error opening serial port: " + e.toString());
  }
  print("Successfully opened serial port!");
  
  String test = "Test message!";
  byte[] test_bytes = test.getBytes();
  try {
    serialPort.output.write(test_bytes);
  } catch(IOException e) {
    print("Error writing to serial port: " + e.toString());
  }
}

void draw() {
  //print("Test");
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


