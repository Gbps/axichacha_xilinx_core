
`timescale 1ns / 1ps

module axichacha_dma_v1_0_tb();

// Defined from iverilog command line

// NUMBLOCKS = Number of 512-bit blocks
`ifndef NUMBLOCKS
`define NUMBLOCKS 16
`endif

// NUMBIGBLOCKS = Number of (NUMBLOCKS * 512) chunks in the total payload
`ifndef NUMBIGBLOCKS
`define NUMBIGBLOCKS 1
`endif

`ifndef TDATAWIDTH
`define TDATAWIDTH 32
`endif

// Defined in iverilog
  localparam NUMBER_OF_BLOCKS = `NUMBLOCKS;

  localparam C_S_AXI_ADDR_WIDTH = 32;
  localparam C_S_AXI_DATA_WIDTH = 32;

// Defined in iverilog
  localparam AXIS_TDATA_WIDTH = `TDATAWIDTH;

  localparam VERSION_EXPECTED = 32'h10000000;

  localparam ADDR_VERSION = 32'h00;
  localparam ADDR_CONTROL = 32'h04;
  localparam ADDR_KEY = 32'h08;
  localparam ADDR_IV = 32'h28;
  localparam ADDR_DATA_SIZE = 32'h34;

  localparam CONTROL_RESETN = 32'h00;
  localparam CONTROL_DATA_VALID = 32'h01;


  localparam SIZE_DATA_BITS = NUMBER_OF_BLOCKS * 512;
  localparam SIZE_DATA_WORDS = SIZE_DATA_BITS/32;
  localparam SIZE_TOTAL_WORDS = SIZE_DATA_WORDS * `NUMBIGBLOCKS;

  localparam SIZE_KEY_WORDS = 8;
  localparam SIZE_IV_WORDS = 3;

  reg [31:0] key [0:SIZE_KEY_WORDS-1];
  reg [31:0] iv [0:SIZE_IV_WORDS-1];
  reg [31:0] input_plaintext [0:SIZE_TOTAL_WORDS-1];
  reg [31:0] final_data_in [0:SIZE_DATA_WORDS-1];
  reg [31:0] final_data_out [0:SIZE_DATA_WORDS-1];
  reg [31:0] expected_ciphertext [0:SIZE_TOTAL_WORDS-1];

// Buffer for writes and reads from mem
  reg [AXIS_TDATA_WIDTH-1:0] axis_buffer = 0;

  reg s_axi_aclk = 0; // AXI4-Lite Clock
  reg aresetn = 0; // AXI4-Lite Reset

  reg s_axi_aresetn = 0; // AXI4-Lite interface reset
  reg  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr = 0; // Address
  reg s_axi_awvalid = 0; // Write address valid
  wire  s_axi_awready; // Write address ready
  reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata = 0; // Write data
  reg s_axi_wvalid = 0; // Write data valid
  wire s_axi_wready; // Write data ready
  wire [1:0] s_axi_bresp; // Write response
  wire s_axi_bvalid; // Write response valid
  reg s_axi_bready = 0; // Write response ready
  reg [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr = 0; // Read address
  reg s_axi_arvalid = 0; // Read address valid
  wire s_axi_arready; // Read address ready
  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata; // Read data
  wire [1:0] s_axi_rresp; // Read response
  wire s_axi_rvalid; // Read data valid
  reg s_axi_rready = 0; // Read data ready

  wire m00_axis_tvalid;
  wire [AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata;
  wire [(AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb;
  wire m00_axis_tlast;
  reg m00_axis_tready = 0;

  wire s00_axis_tready;
  reg [AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata = 0;
  reg [(AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb = 0;
  reg s00_axis_tlast = 0;
  reg s00_axis_tvalid = 0;

// Define clock
  always #1 s_axi_aclk = ~s_axi_aclk;

  axichacha_dma_v1_0
  #(.NUMBER_OF_BLOCKS(NUMBER_OF_BLOCKS),
    .C_S00_AXIS_TDATA_WIDTH(AXIS_TDATA_WIDTH),
    .C_M00_AXIS_TDATA_WIDTH(AXIS_TDATA_WIDTH) )
  dut (

    .s00_axis_aclk(s_axi_aclk),
    .s00_axis_aresetn(s_axi_aresetn),
    .s00_axis_tready(s00_axis_tready),
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tstrb(s00_axis_tstrb),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),

    .m00_axis_aclk(s_axi_aclk),
    .m00_axis_aresetn(s_axi_aresetn),
    .m00_axis_tvalid(m00_axis_tvalid),
    .m00_axis_tdata(m00_axis_tdata),
    .m00_axis_tstrb(m00_axis_tstrb),
    .m00_axis_tlast(m00_axis_tlast),
    .m00_axis_tready(m00_axis_tready),

    .s00_axi_aclk(s_axi_aclk),
    .s00_axi_aresetn(s_axi_aresetn),
    .s00_axi_awaddr(s_axi_awaddr),
    .s00_axi_awvalid(s_axi_awvalid),
    .s00_axi_awready(s_axi_awready),
    .s00_axi_wdata(s_axi_wdata),
    .s00_axi_wvalid(s_axi_wvalid),
    .s00_axi_wready(s_axi_wready),
    .s00_axi_bresp(s_axi_bresp),
    .s00_axi_bvalid(s_axi_bvalid),
    .s00_axi_bready(s_axi_bready),
    .s00_axi_araddr(s_axi_araddr),
    .s00_axi_arvalid(s_axi_arvalid),
    .s00_axi_arready(s_axi_arready),
    .s00_axi_rdata(s_axi_rdata),
    .s00_axi_rresp(s_axi_rresp),
    .s00_axi_rvalid(s_axi_rvalid),
    .s00_axi_rready(s_axi_rready)
  );

  function [31 : 0] big2little (input [31 : 0] op);
    begin
      big2little = {op[7 : 0], op[15 : 8], op[23 : 16], op[31 : 24]};
    end
  endfunction

`define assert(comparison) \
  if (~(comparison)) begin \
      $display("ASSERTION FAILED in %m: comparison"); \
      $finish; \
  end

// Test read and writes
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars();

    $readmemh("./test_files/key", key);
    $readmemh("./test_files/iv", iv);
    $readmemh("./test_files/plaintext", input_plaintext);
    $readmemh("./test_files/ciphertext", expected_ciphertext);

    @(posedge s_axi_aclk);
    @(posedge s_axi_aclk);

    // Take the core out of reset
    aresetn = 1;
    s_axi_aresetn = 1;

    @(posedge s_axi_aclk);
    @(posedge s_axi_aclk);

    // Read the value at address 0x00 (Version)
    enforce_axi_read(ADDR_VERSION, VERSION_EXPECTED);

    // Expect core to be in reset state
    enforce_axi_read(ADDR_CONTROL, (0 << CONTROL_RESETN));

    // Test writing to read-only register
    axi_write_and_read(ADDR_VERSION, 32'hdeadbeef, VERSION_EXPECTED);

    // Write a key
    for (integer i = 0; i < SIZE_KEY_WORDS; i = i + 1) begin
      axi_write_and_read(ADDR_KEY + i*4, key[i], key[i]);
    end

    // Write an IV
    for (integer i = 0; i < SIZE_IV_WORDS; i = i + 1) begin
      axi_write_and_read(ADDR_IV + i*4, iv[i], iv[i]);
    end

    // Confirm data size is what we expect
    enforce_axi_read(ADDR_DATA_SIZE, SIZE_DATA_BITS / 8);

    // Take the core out of reset
    axi_write(ADDR_CONTROL, (1 << CONTROL_RESETN));

    // Expect the core is out of reset
    enforce_axi_read(ADDR_CONTROL, (1 << CONTROL_RESETN));

    for (integer current_block_i = 0; current_block_i < `NUMBIGBLOCKS; current_block_i = current_block_i + 1) begin

      // Writes start on the negedge
      @(negedge s_axi_aclk);

      $display("Writing plaintext...");

      // Write data to encrypt to the device, split each chunk of data into the AXIS data size
      for(integer i = 0; i < SIZE_DATA_BITS; i = i + AXIS_TDATA_WIDTH) begin
        for (integer j = 0; j < AXIS_TDATA_WIDTH; j = j + 32) begin
          axis_buffer[j +: 32] = input_plaintext[i/32 + j/32 + (current_block_i*SIZE_DATA_WORDS)];
        end

        axis_write(axis_buffer);
      end

      $display("put plaintext: %x", dut.axichacha_inst.data_in);

      // Wait awhile for crypt to finish
      #100;

      // Expect data is available in the control register
      enforce_axi_read(ADDR_CONTROL, (1 << CONTROL_DATA_VALID) | (1 << CONTROL_RESETN));

      // AXI-S reads must start on the negedge
      @(negedge s_axi_aclk);

      $display("got ciphertext: %x", dut.axichacha_inst.data_out);

      // Read the encrypted data back
      for(integer i = 0; i < SIZE_DATA_BITS; i = i + AXIS_TDATA_WIDTH) begin
        axis_read(axis_buffer);
        for (integer j = 0; j < AXIS_TDATA_WIDTH; j = j + 32) begin
          final_data_out[i/32 + j/32] = axis_buffer;
        end
      end

      // Verify it matches the python version
      for(integer i = 0; i < SIZE_DATA_BITS; i = i + 32) begin
        if (final_data_out[i] != expected_ciphertext[i + (current_block_i*SIZE_DATA_WORDS)]) begin
          $display("TEST FAILED: Ciphertext mismatch. data_out=%x expected=%x", final_data_out[i], expected_ciphertext[i]);
          $finish;
        end
      end

    end

    $display("Test completed successfully!");

    $finish;
  end

// Write to an AXI-S slave
  task automatic axis_write;
    input [AXIS_TDATA_WIDTH - 1 : 0] data_to_write;
    begin
      // Make data valid
      s00_axis_tdata = data_to_write;
      s00_axis_tvalid = 1;
      s00_axis_tstrb = 8'hff;
      s00_axis_tlast = 0;

      // Wait for transfer
      wait(s00_axis_tready);
      @(negedge s_axi_aclk);

      s00_axis_tdata = 0;
      s00_axis_tvalid = 0;
      s00_axis_tstrb = 8'hff;
      s00_axis_tlast = 0;
    end
  endtask

// Read data from an AXI-S master
  task automatic axis_read;
    output [AXIS_TDATA_WIDTH - 1 : 0] data_read;
    begin
      // Make us ready to receive data
      m00_axis_tready = 1;

      // Wait for transfer
      wait(m00_axis_tvalid);
      data_read = m00_axis_tdata;
      @(negedge s_axi_aclk);
      m00_axis_tready = 0;
    end
  endtask

///////////////////// AXI HELPER TASKS ///////////////////////////

  task automatic axi_read;
    input [C_S_AXI_ADDR_WIDTH - 1 : 0] addr;
    output [C_S_AXI_DATA_WIDTH - 1 : 0] data_out;
    begin
      s_axi_araddr = addr;
      s_axi_arvalid = 1;
      s_axi_rready = 1;
      wait(s_axi_arready);
      wait(s_axi_rvalid);

      data_out = s_axi_rdata;
      if (s_axi_rresp != 2'b00) begin
        $display("Error: RRESP responded with error: %x",s_axi_rresp);
        $finish;
      end

      @(posedge s_axi_aclk) #1;
      s_axi_arvalid = 0;
      s_axi_rready = 0;

    end
  endtask

  task automatic enforce_axi_read;
    input [C_S_AXI_ADDR_WIDTH - 1 : 0] addr;
    input [C_S_AXI_DATA_WIDTH - 1 : 0] expected_data;
    reg [C_S_AXI_DATA_WIDTH - 1 : 0] read_data;
    begin
      // Read from the slave
      axi_read(addr, read_data);

      if (read_data != expected_data) begin
        $display("Error: Mismatch in AXI4 read at %x: ", addr,
          "expected %x, received %x",
          expected_data, s_axi_rdata);
        #10;
        $finish;
      end

      if (s_axi_rresp != 2'b00) begin
        $display("Error: RRESP responded with error: %x",s_axi_rresp);
        $finish;
      end

    end
  endtask

  task automatic test_slave_read_error;
    input [C_S_AXI_ADDR_WIDTH - 1 : 0] addr;
    begin
      s_axi_araddr = addr;
      s_axi_arvalid = 1;
      s_axi_rready = 1;
      wait(s_axi_arready);
      wait(s_axi_rvalid);

      if (s_axi_rresp != 2'b10) begin
        $display("Error: Mismatch in AXI4 slave error test at %x: ", s_axi_araddr,
          "expected rresp=%x, received rresp=%x",
          2'b10, s_axi_rresp);
        $finish;
      end

      @(posedge s_axi_aclk) #1;
      s_axi_arvalid = 0;
      s_axi_rready = 0;
    end
  endtask

  task automatic test_slave_write_error;
    input [C_S_AXI_ADDR_WIDTH - 1 : 0] addr;
    input [C_S_AXI_DATA_WIDTH - 1 : 0] data;
    begin
      s_axi_wdata = data;
      s_axi_awaddr = addr;
      s_axi_awvalid = 1;
      s_axi_wvalid = 1;
      wait(s_axi_awready && s_axi_wready);

      if (s_axi_bresp != 2'b10) begin
        $display("Error: Mismatch in write slave error test at %x: ", s_axi_araddr,
          "expected rresp=%x, received rresp=%x",
          2'b10, s_axi_bresp);
        $finish;
      end

      @(posedge s_axi_aclk) #1;
      s_axi_awvalid = 0;
      s_axi_wvalid = 0;
    end
  endtask


  task automatic axi_write;
    input [C_S_AXI_ADDR_WIDTH - 1 : 0] addr;
    input [C_S_AXI_DATA_WIDTH - 1 : 0] data;
    begin
      s_axi_wdata = data;
      s_axi_awaddr = addr;
      s_axi_awvalid = 1;
      s_axi_wvalid = 1;
      wait(s_axi_awready && s_axi_wready);

      if (s_axi_bresp != 2'b00) begin
        $display("Error: axi_write: bresp=", s_axi_bresp);
        $finish;
      end

      @(posedge s_axi_aclk) #1;
      s_axi_awvalid = 0;
      s_axi_wvalid = 0;
    end
  endtask

// Write a value and read the same address back expecting a value
  task automatic axi_write_and_read;
    input [C_S_AXI_ADDR_WIDTH - 1 : 0] addr;
    input [C_S_AXI_DATA_WIDTH - 1 : 0] data;
    input [C_S_AXI_DATA_WIDTH - 1 : 0] data_expected;
    begin
      // Write the data
      axi_write(addr, data);

      // Read it back and confirm it
      enforce_axi_read(addr, data_expected);
    end
  endtask

endmodule