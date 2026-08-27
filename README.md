# Edge-Anamoly-Detector
RISC-V based edge anomaly detection system for industrial sensor monitoring using Python sensor simulation, ring buffers, threshold detection, rate-of-change analysis, and interrupt-style alerts.


# Edge Anomaly Detector

An edge-based industrial machine monitoring and anomaly detection project built using **RISC-V Assembly** and **Python**.

The project simulates sensor readings from an industrial machine and processes them using RISC-V assembly. It checks the sensor readings for unusual values or sudden changes. When an anomaly is detected, the system generates an alert.

## Features

* Simulates industrial sensor data using Python
* Monitors temperature, vibration, pressure, and humidity
* Generates 200 sensor ticks with 800 readings in total
* Uses ring buffers to store recent sensor readings
* Detects abnormal sensor values
* Detects sudden changes in sensor readings
* Uses bitmasks to identify different types of anomalies
* Generates interrupt-style alerts
* Displays the sensor, tick, anomaly type, and detected value
* Keeps track of the total number of alerts

## Project Structure

```text
edge-anamoly-detector/
│
├── main.asm
├── buffer.asm
├── detect.asm
├── interrupt.asm
├── sensor_stream.py
```

### main.asm

This is the main program.

It reads the sensor data, stores the readings, runs the anomaly detection logic, and displays the results.

### buffer.asm

This file implements the ring buffers used to store recent sensor readings.

The buffers help the system keep track of previous values so that sudden changes can be detected.

### detect.asm

This file contains the anomaly detection logic.

It checks whether sensor readings are outside their allowed limits or whether there is a sudden change from the previous reading.

### interrupt.asm

This file handles the response when an anomaly is detected.

It records the alert, identifies the affected sensor, and displays the relevant information.

### sensor_stream.py

This Python program acts as a sensor simulator.

It generates readings for temperature, vibration, pressure, and humidity. It also adds some random variation and predefined abnormal readings to test the detection system.

## Sensor Data

The system works with four types of sensor readings:

* Temperature
* Vibration
* Pressure
* Humidity

The Python simulator generates **800 readings** in total.

The values are stored as integers scaled by 100 so that the RISC-V program can process them without using floating-point calculations. It is generated after running the python file sensor_stream.py

The generated sensor data is stored locally in:

```text
asm/sensor_data.txt
```

## Anomaly Detection

The system detects anomalies in two main ways:

### Threshold Detection

The program checks whether a sensor value is too high or too low compared to its allowed range.

### Rate-of-Change Detection

The program compares the current reading with the previous reading. If the value changes too quickly, it is treated as an anomaly.

The system can also identify more than one anomaly condition at the same time using a bitmask.

## How to Run

### Step 1: Generate Sensor Data

Run the Python sensor simulator:

```bash
python sensor_stream.py
```

This generates the sensor data required by the RISC-V program.

### Step 2: Run the RISC-V Program

Install or download **RARS** separately and place the RARS JAR file in the project folder.

Then run:

```bash
java -jar rars.jar sm main.asm
```

The `sm` option starts the program from the `main` label.

## Detection Process

The project follows this basic process:

```text
Python Sensor Simulator
        ↓
Sensor Data
        ↓
RISC-V Program
        ↓
Ring Buffers
        ↓
Anomaly Detection
        ↓
Interrupt-Style Alert
        ↓
Display Results
```

## Purpose

The main purpose of this project is to demonstrate how sensor data can be processed directly at the edge using low-level programming.

The project demonstrates concepts such as:

* RISC-V Assembly programming
* Sensor data processing
* Ring buffers
* Memory management
* Threshold-based detection
* Rate-of-change detection
* Bitmask-based event handling
* Interrupt-style processing
* Python-based sensor simulation

## Future Improvements

Possible improvements include:

* Adding more sensors
* Adding more detection methods
* Making thresholds configurable
* Adding real-time sensor input
* Connecting the system to physical sensors
* Adding a graphical interface for sensor readings and alerts

## Requirements

* Python 
* Java
* RARS 1.6 or a compatible RISC-V simulator
