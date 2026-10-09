# 🛰️ CCSDS Telemetry Frame De-serializer & CRC Engine

A lightweight, fault-tolerant **CCSDS Telemetry Frame De-serializer & CRC-16 Verification Engine** designed in Verilog HDL. Implemented as a hardware sub-system for small satellites (CubeSats/Nanosats) to handle high-throughput downlink telemetry parsing and validate frame integrity on-the-fly.

Developed as a digital logic implementation project celebrating **World Space Week**.

---

## 📌 Architecture Overview

Spacecraft downlinks stream continuous raw binary telemetry prone to bit flips caused by cosmic radiation and Single Event Upsets (SEUs). This IP core implements a **4-state Finite State Machine (FSM)** to align serial data, parse CCSDS header fields, and drop corrupted telemetry frames before passing payload data to the flight processor.

```
                    ┌─────────────────────────┐
                    │    STATE_SYNC_SEARCH    │ ◄─── Resets CRC to 0xFFFF
                    └────────────┬────────────┘      Matches 0x1ACFFC1D
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │      STATE_HEADER       │ ◄─── Extracts 4-Byte Header
                    └────────────┬────────────┘      Accumulates CRC-16
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │      STATE_PAYLOAD      │ ◄─── Streams Byte Payload
                    └────────────┬────────────┘      Accumulates CRC-16
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │    STATE_CRC_CHECK      │ ◄─── Asserts frame_valid
                    └─────────────────────────┘      or crc_error flag

```

### Key Engineering Features

* **CCSDS Compliance:** Aligns bit streams to the standard 32-bit synchronization marker (`0x1ACFFC1D`).
* **Hardware Error Detection:** Computes bit-wise MSB-first **CRC-16 CCITT** (Polynomial `0x1021`, Initial Seed `0xFFFF`) directly over streaming bytes.
* **Low Latency Pipeline:** Single-cycle pulse outputs (`payload_valid`, `frame_valid`, `crc_error`) allow direct interfacing with downstream FIFO buffers or AXI4-Stream IPs.
* **Fault Injection Resilient:** Tested against simulated Single Event Upsets (SEUs) to verify corrupt frame rejection.

---

## 📁 Repository Structure

```
.
├── ccsds_deserializer.v     # Core Verilog RTL Module
├── tb_ccsds_deserializer.v  # Self-checking Testbench with Debug Tracing
└── README.md                # Documentation

```

---

## 🚀 Quickstart & Simulation

This design is toolchain-agnostic and runs on open-source tools like **Icarus Verilog** and **GTKWave**.

### Prerequisites

Install Icarus Verilog on Linux / WSL:

```bash
sudo apt update
sudo apt install iverilog gtkwave

```

### Running Testbench Simulation

Clone the repository and run the pre-configured simulation script:

```bash
# 1. Compile Verilog sources
iverilog -o ccsds_sim ccsds_deserializer.v tb_ccsds_deserializer.v

# 2. Run simulation
vvp ccsds_sim

```

### Expected Terminal Output

```text
=== STARTING CCSDS FRAME DE-SERIALIZER SIMULATION ===

[TEST 1] Sending Noise + Valid Telemetry Frame...
[RTL DEBUG] >>> SYNC DETECTED!
[RTL DEBUG] Received Full CRC = 0x5856 | Calculated CRC = 0x5856
[RTL DEBUG] *** CRC MATCH! ***
[PASS] Frame successfully decoded and CRC verified!

[TEST 2] Sending Frame with Corrupted Data Bit (SEU)...
[RTL DEBUG] >>> SYNC DETECTED!
[RTL DEBUG] Received Full CRC = 0x5856 | Calculated CRC = 0xc209
[RTL DEBUG] *** CRC MISMATCH! ***
[PASS] CRC Engine correctly identified corrupted frame!

=== SIMULATION COMPLETE ===

```

---

## 📊 Module Pinout & Parameters

### RTL Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `PAYLOAD_BYTES` | `8` | Number of payload data bytes expected per frame |

### Signals Interface

| Signal | Type | Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | `1` | System Clock |
| `rst_n` | Input | `1` | Active-Low Asynchronous Reset |
| `rx_byte` | Input | `8` | Incoming streaming data byte |
| `rx_valid` | Input | `1` | Asserted when `rx_byte` contains valid stream data |
| `frame_header` | Output | `32` | Parsed 4-Byte Space Packet Header |
| `payload_byte` | Output | `8` | Extracted telemetry payload byte |
| `payload_valid` | Output | `1` | Single-cycle pulse per valid payload byte |
| `frame_valid` | Output | `1` | Asserted when full frame passes CRC-16 check |
| `crc_error` | Output | `1` | Asserted when CRC mismatch is detected |

---

## 🛰️ Real-World Space Applications

This module mimics sub-systems deployed across several spaceflight domains:

* **CubeSat Telemetry Downlinks:** Strips CCSDS headers from raw S-band / UHF RF bitstreams before storing data to onboard storage.
* **Flight Computer Hardware Offloading:** Offloads frame parsing and CRC-16 computation from the main micro-controller (OBC) to save clock cycles.
* **SEU-Resilient Payload Pipelines:** Filters out corrupt packets caused by space radiation and bit flips before passing image or sensor data downstream.
* **Ground Station SDR Terminals:** Acts as the hardware front-end in FPGA-accelerated ground station receivers to validate downlinked spacecraft health data.

---

## 📜 Standard References

* **CCSDS 132.0-B-2:** *TM Space Data Link Protocol* (Section 4 — Frame Synchronization & Error Control)
* **CCSDS 130.0-G-3:** *Overview of Space Communications Protocols*

---

## 👩‍💻 Author

**Vaishnavi Mudaliar**

*Project created for World Space Week*

---
