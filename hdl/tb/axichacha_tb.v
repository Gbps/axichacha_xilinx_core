
`timescale 1ns / 1ps

module axichacha_tb();
localparam NUMBER_OF_BLOCKS = 1;

localparam C_S_AXI_ADDR_WIDTH = 32;
localparam C_S_AXI_DATA_WIDTH = 32;

localparam VERSION_EXPECTED = 32'h10000000;

localparam ADDR_VERSION = 32'h00;
localparam ADDR_CONTROL = 32'h04;
localparam ADDR_KEY = 32'h08;
localparam ADDR_IV = 32'h28;
localparam ADDR_DATA_SIZE = 32'h34;
localparam ADDR_DATA_IN = 32'h10000;
localparam ADDR_DATA_OUT = 32'h20000;

localparam CONTROL_RESETN = 32'h00;
localparam CONTROL_DATA_VALID = 32'h01;


localparam SIZE_DATA_BITS = NUMBER_OF_BLOCKS * 512;
localparam SIZE_KEY_BITS = 256;
localparam SIZE_IV_BITS = 96;

reg [SIZE_KEY_BITS-1:0] key;
reg [SIZE_IV_BITS-1:0] iv;
reg [SIZE_DATA_BITS-1:0] input_plaintext;
reg [SIZE_DATA_BITS-1:0] final_data_in;
reg [SIZE_DATA_BITS-1:0] final_data_out;
reg [SIZE_DATA_BITS-1:0] expected_ciphertext;

reg          s_axi_aclk = 0;      // AXI4-Lite Clock
reg          aresetn = 0;   // AXI4-Lite Reset

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


// Define clock
always #1 s_axi_aclk = ~s_axi_aclk;

axichacha
#(.NUMBER_OF_BLOCKS(NUMBER_OF_BLOCKS) )
dut (
    .aclk(s_axi_aclk),
    .aresetn(aresetn),
    .s_axi_aresetn(s_axi_aresetn),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready)
);

// Test read and writes
initial begin
    $dumpfile("axichacha_tb.vcd");
    $dumpvars(0, dut);

    key = 256'h0000000000000001000000020000000300000004000000050000000600000007;
    iv = 96'h00000008000000090000000a;
    input_plaintext = 512'h0000000a0000000b0000000c0000000d0000000e0000000f00000010000000110000001200000013000000140000001500000016000000170000001800000019;
    expected_ciphertext = 512'h1236d43529a40070fe6d5c51b5ede86ed821a781d1841b1ebb40a22ba3057cabcd09d75c968ed6923ceb075cdb69602b575184404bf5f44273dbf01080eca00e;

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
    for (integer i = 0; i < SIZE_KEY_BITS/32; i = i + 1) begin
      axi_write_and_read(ADDR_KEY + i*4, key[i*32 +: 32], key[i*32 +: 32]);
    end

    // Write an IV
    for (integer i = 0; i < SIZE_IV_BITS/32; i = i + 1) begin
      axi_write_and_read(ADDR_IV + i*4, iv[i*32 +: 32], iv[i*32 +: 32]);
    end
    
    // Confirm data size is what we expect
    enforce_axi_read(ADDR_DATA_SIZE, SIZE_DATA_BITS / 8);

    // Write data to encrypt to the device
    for(integer i = 0; i < SIZE_DATA_BITS/32; i = i + 1) begin
      axi_write_and_read(ADDR_DATA_IN + i*4, input_plaintext[i*32 +: 32], input_plaintext[i*32 +: 32]);
    end

    // Take the core out of reset
    axi_write(ADDR_CONTROL, (1 << CONTROL_RESETN));
    // Expect the core is out of reset
    enforce_axi_read(ADDR_CONTROL, (1 << CONTROL_RESETN));

    // Wait for device to tell us data has been encrypted and is ready to read
    @(posedge s_axi_aclk);

    // Ensure device does not say data is valid too quickly
    enforce_axi_read(ADDR_CONTROL, (0 << CONTROL_DATA_VALID) | (1 << CONTROL_RESETN));

    // Wait awhile
    #100;

    // Expect data is available in the control register
    enforce_axi_read(ADDR_CONTROL, (1 << CONTROL_DATA_VALID) | (1 << CONTROL_RESETN));

    for(integer i = 0; i < SIZE_DATA_BITS/32; i = i + 1) begin
      axi_read(ADDR_DATA_IN + i*4, final_data_in[i*32 +: 32]);
    end
    // Read the encrypted data back
    for(integer i = 0; i < SIZE_DATA_BITS/32; i = i + 1) begin
      axi_read(ADDR_DATA_OUT + i*4, final_data_out[i*32 +: 32]);
    end

    $display("Key: %x", key);
    $display("IV: %x", iv);
    $display("Plaintext: %x", final_data_in);
    $display("Ciphertext: %x", final_data_out);

    $display("Test completed successfully!");

    $finish;
end

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