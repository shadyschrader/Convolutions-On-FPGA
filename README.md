# Convolutions on FPGA

## Overview

This project implements a hardware-accelerated 2D convolution engine using Verilog, optimized for FPGA deployment. It processes a **128×128 grayscale image** (8-bit per pixel) with a **3×3 convolution filter**, producing a **126×126 output feature map** (16-bit per pixel). 

Key highlights:
- **Preloaded input image** via `.coe` file.
- **Modular Verilog design**.
- **Testbench for simulation** included.
- Suitable for **image processing acceleration** on FPGA.

## Parameters

| Name          | Value      | Description                        |
|---------------|------------|------------------------------------|
| IMAGE_WIDTH   | 128        | Width of the input image           |
| IMAGE_HEIGHT  | 128        | Height of the input image          |
| FILTER_SIZE   | 3          | Convolution filter size (3x3)      |
| OUTPUT_SIZE   | 126        | Output size (128 - 3 + 1)          |

---

## How It Works

### 🔧 Initialization
- Input BRAM is preloaded using a `.coe` file.
- 3×3 convolution filter is provided as an input array (8-bit per value).

### Processing Flow
1. **FSM transitions** from `IDLE` → `PROCESS`.
2. **Load Module** reads rows into a buffer.
3. **Shift Module** generates 3×3 windows.
4. **Convolve Module** applies the filter and computes each output.
5. **Output** is stored into the output BRAM.
6. FSM enters `STORE_OUT` and asserts the `done` signal.

---

## I/O Interface

### Inputs:
- `clk` – Clock signal
- `rst` – Reset signal
- `filter` – 3x3 filter matrix (array of 9 × 8-bit values)

### Outputs:
- `result` – Placeholder (16-bit × 126×126); pending implementation
- `load_done`, `shift_done`, `convolve_done`, `done` – FSM status flags

---

## Simulation

### Requirements:
- Verilog simulator (e.g., ModelSim, Vivado Simulator)
- `.mem` file version of input image (converted from `.coe`)



🛠 Synthesis

    Convert input image to .coe format.