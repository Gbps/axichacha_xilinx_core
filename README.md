# [WIP] Xilinx ChaCha20 Block Designer Core

This is an AXI4 ChaCha20 encrypt/decrypt core that's intended to be used with the Xilinx block designer. It contains a simple Python testbench to verify its correctness.

**This is not suitable for production code.**

The intention is that this is to be used with my FPGA AXI DMA ChaCha20 accelerator project.



# Usage instructions

- Clone the folder into your IP repo for Vivado
- Refresh the IP repro in Vivado
- Add the design to the block designer
- Configure the design with the proper AXI-S bus width.
  - `NUMBER_OF_BLOCKS` is the number of 512-bit blocks that are crypted in parallel.

# Testing instructions

- To test the core, run: `./hdl/tb/bin/run_axichacha_dma_v1_0_tb.sh` on a Linux machine or WSL.
  - This will test a series of bus widths and block sizes and open gtkwave to view the results.
  - This test bench uses `iverilog` and `gtkwave` for speed since Vivado's simulator is so slow for basic testing.
