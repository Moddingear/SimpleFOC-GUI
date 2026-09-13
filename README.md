# SimpleFOC-GUI
A GUI for SimpleFOC, made in godot, built to be easily modifyable in the editor

## Usage
For now, only motors are supported, but PID, fields and such could also be supported.

Setup for a motor:
```cpp
#include <communication/Commander.h>

//have your motor/simplefoc definition somewhere
Commander commander(Serial);

void OnMotor(char* cmd)
{
  commander.motor(&motor, cmd);
}

void setup()
{
  ...
  motor.useMonitoring(Serial);
  commander.add("M", OnMotor, "motor 0");
  ...
}

void loop()
{
  ...
  motor.monitor();
  commander.run();
  ...
}
```

As long as `motor.monitor()` runs at the same speed as `motor.loop()` and `motor.loopFOC()`, the computed loop frequency from monitor will be accurate enough.
