# Convolutions on FPGA
## Overview
This project implements a hardware-based convolution engine in Verilog, designed for FPGA deployment. The module processes a 128x128 grayscale image (8-bit per pixel) using a 3x3 filter to produce a 126x126 output feature map (16-bit per element). The input image is preloaded into a Block RAM (BRAM) using a .coe file, eliminating the need for runtime image loading. The design is parameterized, modular, and includes a testbench for simulation-based verification.
Project Status
The project is in active development, with the following components completed or in progress:
1. Top Module Design

Purpose: The top module orchestrates the convolution pipeline, interfacing with input and output BRAMs and coordinating submodules for loading, shifting, and convolving image data.
Parameters:
IMAGE_WIDTH = 128: Image width in pixels.
IMAGE_HEIGHT = 128: Image height in pixels.
FILTER_SIZE = 3: Size of the convolution filter (3x3).
OUT = 126: Output feature map size (calculated as IMAGE_HEIGHT - FILTER_SIZE + 1).


Inputs/Outputs:
Inputs: clk, rst, filter (3x3 filter, 8-bit per element).
Outputs: result (126x126 output, 16-bit per element, currently a placeholder), load_done, shift_done, convolve_done, done (status signals).


Key Features:
Uses a dual-port input BRAM (input_image_bram) preloaded with a .coe file containing the 128x128 image.
Uses a single-port output BRAM (output_image_bram) to store convolution results.
Implements a two-level finite state machine (FSM):
Main states: IDLE, PROCESS, STORE_OUT.
Process states: LOAD, SHIFT, CONVOLVE, STORE.


Removed the image input port and LOAD_IMG state, as the input BRAM is preloaded, simplifying the design.



2. Submodules

Load Module: Reads rows from the input BRAM to form a row buffer for convolution.
Shift Module: Shifts the row buffer to create 3x3 windows for convolution.
Convolve Module: Performs the convolution operation on each 3x3 window using the provided filter.
Status: All submodules are instantiated and integrated, but their internal implementations are assumed to be complete (not provided in the project scope).

3. BRAM Integration

Input BRAM:
Dual-port, 16384 elements (128x128), 8-bit per element.
Preloaded with a .coe file containing the 128x128 image data.
Port A used for initialization (if needed); Port B used for reading during processing.


Output BRAM:
Single-port, 15876 elements (126x126), 16-bit per element.
Stores convolution results during the STORE state.


Status: Placeholder BRAM modules are provided for simulation. Actual implementations (e.g., Vivado-generated BRAMs) are required for synthesis.

4. Testbench Development

Purpose: Verifies the convolution engine’s functionality through simulation.
Features:
Simulates a 100MHz clock and reset sequence.
Provides a sample 3x3 edge-detection filter.
Assumes the input BRAM is preloaded with a .coe file (simulated via $readmemh with a .mem file).
Monitors FSM states and status signals (load_done, shift_done, convolve_done, done).
Reads and displays the first 10 elements of the output BRAM after convolution completes.
Generates a VCD file (convolution_tb.vcd) for waveform analysis.


Status: The testbench is complete and aligned with the modified top module (no image input). It supports simulation but requires actual BRAM implementations and a .coe file for full verification.

5. Modifications and Optimizations

Removed image Input: Initially, the design included an image input port for loading the BRAM at runtime. This was removed, as the input BRAM is preloaded with a .coe file, reducing I/O requirements.
Simplified FSM: Eliminated the LOAD_IMG state, allowing the module to process preloaded BRAM data directly after reset.
Placeholder result Output: The result output is currently assigned to 0. A mechanism to serialize output BRAM data to result is pending implementation.

Project Structure

Files:
top.v: Main convolution module.
convolution_tb.v: Testbench for simulation.
load.v, shift.v, convolve.v: Submodules (assumed implemented).
input_image_bram.v, output_bram.v: Placeholder BRAM modules (replace with actual implementations).
image_128x128.coe or .mem: Input image data (user-provided).


Directory:convolution_project/
├── src/
│   ├── top.v
│   ├── load.v
│   ├── shift.v
│   ├── convolve.v
│   ├── input_image_bram.v
│   ├── output_bram.v
├── tb/
│   ├── convolution_tb.v
├── data/
│   ├── image_128x128.coe
│   ├── image_128x128.mem
├── README.md



How It Works

Initialization:
The input BRAM is preloaded with a 128x128 image via a .coe file during synthesis or simulation.
The filter is provided as a 3x3 array (8-bit per element) at runtime.


Processing:
After reset, the FSM transitions from IDLE to PROCESS.
The load module reads rows from the input BRAM.
The shift module creates 3x3 windows.
The convolve module computes the convolution for each window.
Results are stored in the output BRAM.


Completion:
After processing all windows (126x126 outputs), the FSM enters STORE_OUT and asserts done.
The output BRAM contains the convolution results, accessible for verification.



Usage
Synthesis

Use an FPGA tool (e.g., Vivado) to generate the input BRAM with your .coe file.
Replace placeholder BRAM modules with Vivado-generated modules.
Synthesize the design, ensuring the .coe file is correctly associated with the input BRAM.

Simulation

Convert the .coe file to a .mem file for simulation (if required).
Update input_image_bram.v with the correct .mem file path.
Compile and simulate using a Verilog simulator (e.g., ModelSim, Vivado Simulator):vsim -c convolution_tb -do "run -all"


Inspect the console output and convolution_tb.vcd in a waveform viewer (e.g., GTKWave).

Next Steps

Implement result Output: Develop a mechanism to read output BRAM data and serialize it to the result port.
Enhance Verification:
Add test cases with different filters (e.g., blur, Sobel).
Automate output comparison against a golden reference (e.g., computed in Python).


Timing Analysis: Perform static timing analysis to ensure the design meets clock constraints.
BRAM Implementation: Integrate actual Vivado-generated BRAMs with proper .coe initialization.
Documentation: Add detailed comments in Verilog files and document submodule interfaces.

Known Issues

The result output is a placeholder (assign result = 0), limiting external access to convolution results.
Placeholder BRAM modules are used for simulation; actual implementations are needed for synthesis.
Output verification is limited to the first 10 BRAM elements; full verification requires additional scripting.

Contributing
To contribute, please:

Review the existing code and testbench.
Submit pull requests with clear descriptions of changes.
Focus on implementing the result output, enhancing the testbench, or optimizing the design.

License
This project is licensed under the MIT License (pending finalization).
