"""
sensor_stream.py
Simulates four sensor data streams for an industrial machine monitoring system.

Output file: sensor_data.txt
Format: one INTEGER per line, scaled x100 (no decimals, no commas, no header).
  e.g. 50.23 C  ->  5023
       2.47 g   ->  247
       3.01 bar ->  301
       49.8 %   ->  4980

The RARS assembly program reads this file sequentially:
  4 lines per tick (temp, vib, pressure, humidity), 200 ticks = 800 lines total.

Anomaly injection schedule (tick -> sensor, raw float value):
  Tick  30: temperature  95.0  -> 9500  (THRESH_HIGH)
  Tick  60: vibration     9.5  ->  950  (THRESH_HIGH)
  Tick  90: pressure      0.2  ->   20  (THRESH_LOW)
  Tick 120: humidity     88.0  -> 8800  (THRESH_HIGH)
  Tick 150: temperature  97.0  -> 9700  (THRESH_HIGH)
  Tick 170: vibration    10.2  -> 1020  (THRESH_HIGH)
"""

import random
import math

import os
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(PROJECT_DIR, "asm", "sensor_data.txt")
TICKS = 200
SEED = 42

SENSORS = {
    "temperature": {"base": 50.0, "noise": 2.0, "period": 40},
    "vibration":   {"base": 2.5,  "noise": 0.5, "period": 25},
    "pressure":    {"base": 3.0,  "noise": 0.3, "period": 60},
    "humidity":    {"base": 50.0, "noise": 1.5, "period": 80},
}

ANOMALIES = {
    30:  (0, 95.0),
    60:  (1, 9.5),
    90:  (2, 0.2),
    120: (3, 88.0),
    150: (0, 97.0),
    170: (1, 10.2),
}

def read_sensor(name, tick):
    p = SENSORS[name]
    drift = math.sin(2 * math.pi * tick / p["period"]) * p["noise"] * 2
    noise = random.gauss(0, p["noise"])
    return round(p["base"] + drift + noise, 2)

def main():
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    random.seed(SEED)
    print(f"[SensorSim] Writing {TICKS * 4} lines to {OUTPUT_FILE}")
    print(f"[SensorSim] Format: one integer per line, scaled x100")
    print(f"[SensorSim] Order per tick: TEMP, VIBR, PRES, HUMI")
    print(f"[SensorSim] Random seed: {SEED}")

    with open(OUTPUT_FILE, "w") as f:
        for tick in range(1, TICKS + 1):
            temp = read_sensor("temperature", tick)
            vib  = read_sensor("vibration",   tick)
            pres = read_sensor("pressure",    tick)
            hum  = read_sensor("humidity",    tick)

            if tick in ANOMALIES:
                idx, val = ANOMALIES[tick]
                values = [temp, vib, pres, hum]
                values[idx] = val
                temp, vib, pres, hum = values

            # Write 4 lines per tick: each value scaled x100 as plain integer
            f.write(f"{int(round(temp * 100))}\n")
            f.write(f"{int(round(vib  * 100))}\n")
            f.write(f"{int(round(pres * 100))}\n")
            f.write(f"{int(round(hum  * 100))}\n")

    total = TICKS * 4
    print(f"[SensorSim] Done. {total} lines written.")
    print(f"[SensorSim] Anomaly ticks: {sorted(ANOMALIES.keys())}")

if __name__ == "__main__":
    main()
