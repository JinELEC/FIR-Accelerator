# FIR-Accelerator
## Introduction
Finite Impulse Response (FIR) filters are widely used in digital signal processing applications. However, conventional serial architecture has limited throughput due to sequential operations.

This project implements a parameterized pipelined FIR filter accelerator with an AXI4-Stream interface to improve filter performance. A bansline serial FIR core is developed into a 4-way parallel and pipelined architecture. 

The designs were verified using identical low-pass filter coefficients, and performance and resource trade-offs relative to the serial architecture were analyzed by comparing LUT, FF, and DSP resource usage, maximum operating frequency (Fmax), latency, and throughput based on FPAG synthesis results.

## Architecture Overview
The design consists of a baseline serial FIR structure and extended 4-way parallel/pipelined FIR accelerator architecture.

### Serial FIR
The baseline design is implemented as a serial FIR architecture using a sequential MAC (Multiply-Accumulate). Input samples are updated every clock cycle through a shift register, and a single accumulator is used to sequential filter operations. 

Each output is controlled by a state machine. Since all tap operations are performed sequentially, hardware utilization is low, but thorughput is limited.

![Serial FIR Architecture](docs/serial_block_diagram.png)
