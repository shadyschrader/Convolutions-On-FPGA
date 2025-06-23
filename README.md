# Convolutions on FPGA

## Overview

This project aims at convoluting a **128-by-128** Image Matrix using a **3-by-3** Kernel. For this i have used a pipelined approach spanning across 4 states: LOAD, STORE, CONVOLVE, STORE. The convoluted image pixels are stored in the BRAM simulted by using Xilinx Block RAM (BRAM) IP cores. At the end the pixels are streamed out from the output BRAM through the 32-bit *result* port giving us a **126-by-126** Image Matrix. 

## Performance Characteristics

| Parameter | Value |
|-----------|--------|
| Input Resolution | 128×128 pixels |
| Kernel Size | 3×3 |
| Output Resolution | 126×126 pixels |
| Data Width | 32-bit |
| Architecture | 4-stage pipeline |

## Architecture

The implementation utilizes a 4-stage pipelined architecture to maximize throughput and efficiency:

1. LOAD:
    * Extracts a *128-by-3* buffer from the image matrix.
    * Sends this buffer to the SHIFT Block for further processing.
    * This is the core idea behind this whole architecture which i call ***Three-Row-Buffer Method***.

2. SHIFT:
    * From the Three-Row-Buffer a **3-by-3** Matrix is extracted and sent to the CONVOLVE block so that it can be convoluted with the Image Kernel.
    * After each Convolution operation, the next 3-by-3 window is extracted from the buffer and this continues till we extract all windows from the three row buffer. After that, we move to the next buffer by incrementing the row_count.
    * This method reduces the amount of internal registers used. 

3. CONVOLVE 
    * Each 3-by-3 Window which has been obtained from the SHIFT Block is convoluted with a Kernel which has been written in the testbench. 
    * For this project i have used a simple kernel has been used:  
                    |1  0  1|  
                    |1  0  1|   
                    |1  0  1|  
    (*not a standard filter but was used just for verification purposes*)
    * If one wishes to change the filter, one can simply go to the **top_tb.v** file, go to line and change the following task:  
    ```verilog 
        task setup_test_filter;
            begin
                // Simple 3x3 edge detection filter
                filter = {8'h 1, 8'h 0, 8'h 1,  // Top row
                        8'h 1, 8'h 0, 8'h 1,  // Middle row  
                        8'h 1, 8'h 0, 8'h 1}; // Bottom row
                
                $display("Filter setup complete: %h", filter);
            end
        endtask
    ```
    * The method used here is a simple Multiply-Accumulate Operation. We know, MAC operations utilise a huge number of LUTs. However, the approach to multiply just one *3-by-3* window with a Kernel, significantly reduces the number of LUTs required significantly.

4. STORE:
    * An Ouput BRAM was simulated using Xilinx's BRAM IP Core. 
    * After every CONVOLVE block, each pixel got stored in the output BRAM.
    
5. STREAM_OUT:
    * Once the whole 128-by-128 image was convoluted, each pixel got streamed out to the *convolved_output.coe* file.

## Memory Architecture

### Input/Output Storage
The system employs dual Xilinx Block RAM (BRAM) IP cores for optimized memory management:

1. **Input BRAM**: 128×128 pixel storage capacity for source image data
2. **Output BRAM**: 126×126 pixel storage for convolved image results
Memory Latency: Both BRAM modules operate with single-cycle read/write latency for maximum pipeline efficiency

### Data Loading and Preprocessing

* **Input Format**: Pixel values loaded in COE (Coefficient) format
* **Data Generation**: Source images converted using *image_generation.py* preprocessing script
* **Memory Initialization**: BRAM pre-loaded with pixel data during FPGA configuration

### Advantages of On-Chip BRAM

* **High Bandwidth**: Simultaneous multi-port access enabling parallel read/write operations
* **Deterministic Latency**: Consistent single-cycle access time eliminates memory bottlenecks
* **Low Power**: On-chip storage reduces external memory interface power consumption
* **Parallel Access**: Dual-port capability allows concurrent convolution window reads
* **Integration**: Seamless integration with FPGA fabric routing and timing closure

### Output Streaming Architecture

* **Deferred Streaming**: Complete convolution processing occurs before output streaming begins
* **Pipeline Optimization**: Separating convolution and output phases maximizes computational throughput
* **32-bit Data Width**: High-bandwidth result port enables efficient pixel data extraction
* **Sequential Access**: Post-processing streaming maintains pipeline efficiency while delivering results

## Results
* **Simulation Ouput**:

![Simulation Output](Convolutions-On-FPGA/cleaned-repo/assets)

* **Resource Utilization:**
<image>

## Scope for Improvement
### 1. Multiple Pipelines 
* In this project only one pipeline(LOAD --> SHIFT --> CONVOLVE --> STORE) is working at a time.
* The architecture can be expanded to multiple pipelines running at a time.
* For example, the image can be split into 4 parts such as 32-by-128 different images and then for each such buffer, 4 different pipelines can be run.
* This will reduce the simulation time approximatedly by a factor of 4.
* This is one aspect I surely look forward to working on.

### 2. Parallel Pipelines
* The current architecture executes only one state at a time.
* That is, the buffer shifted through the SHIFT state only after the CONVOLVE state finishes it's execution.
* One scope of improvement to this project is that the SHIFT, CONVOLVE and STORE states run in parallel. That is, whenever one convolution operation is over, the next window is kept ready. 
* The aim is to keep the SHIFT, CONVOLVE and STORE states busy all the time. 

