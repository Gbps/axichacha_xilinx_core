`timescale 1 ns / 1 ps

module axichacha #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 32,
    parameter NUMBER_OF_BLOCKS = 1,
    parameter BLOCK_SIZE_BITS = NUMBER_OF_BLOCKS * 512
)
(
    input wire aclk,      // AXI4-Lite Clock
    input wire aresetn,   // AXI4-Lite Reset

    input wire [BLOCK_SIZE_BITS-1:0] data_in,
    input wire next_block, // Prepare for the next block of data to be crypted
    output wire [BLOCK_SIZE_BITS-1:0] data_out,
    output wire data_valid,

    input wire  s_axi_aresetn, // AXI4-Lite interface reset
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr, // Address
    input wire s_axi_awvalid, // Write address valid
    output wire s_axi_awready, // Write address ready
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata, // Write data
    input wire s_axi_wvalid, // Write data valid
    output wire s_axi_wready, // Write data ready
    output wire [1:0] s_axi_bresp, // Write response
    output wire s_axi_bvalid, // Write response valid
    input wire s_axi_bready, // Write response ready
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr, // Read address
    input wire s_axi_arvalid, // Read address valid
    output wire s_axi_arready, // Read address ready
    output reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata, // Read data
    output wire [1:0] s_axi_rresp, // Read response
    output wire s_axi_rvalid, // Read data valid
    input wire s_axi_rready // Read data ready
);

localparam SIZE_4BYTES = 32'd04;
localparam SIZE_KEY = 32'd32;
localparam SIZE_IV = 32'd12;
localparam SIZE_DATA_IN = BLOCK_SIZE_BITS/8;
localparam SIZE_DATA_OUT = BLOCK_SIZE_BITS/8;

localparam ADDR_VERSION = 17'h00;
localparam ADDR_CONTROL = ADDR_VERSION + SIZE_4BYTES;
localparam ADDR_KEY = ADDR_CONTROL + SIZE_4BYTES;
localparam ADDR_IV = ADDR_KEY + SIZE_KEY;
localparam ADDR_DATA_SIZE = ADDR_IV + SIZE_IV;

localparam ADDR_DATA_IN = 16'h1000;
localparam ADDR_DATA_OUT = 16'h2000;
localparam NUM_ADDRESS_BITS = 16;

localparam CONTROL_BIT_RESET = 32'h00;
localparam CONTROL_BIT_DATA_VALID = 32'h01;

localparam VERSION = 32'h10000000;

// The state of read transfers
reg [1:0] read_state;

// ChaCha20 key
reg [255:0] key_reg;

// ChaCha20 IV
reg [95:0] iv_reg;

// The reset state of the chacha core as configured by the control register
reg chacha_core_resetn;

// AXI4-Lite handshake address and data storage
reg [31:0] read_addr_in;
reg [31:0] write_addr_in;
reg [31:0] write_data_in;

// Flags representing data available on each channel
reg read_addr_avail;
reg write_addr_avail;
reg write_data_avail;

// If true, a transfer is taking place and slave is waiting on master to confirm it
reg read_xfer_complete;
reg write_xfer_complete;

// 1 if the data is valid in the chacha core
wire chacha_core_data_valid;

assign data_valid = chacha_core_data_valid;

// The value of the control register when read from the master
wire [31:0] control_register_value;
assign control_register_value = {30'h0, chacha_core_data_valid, chacha_core_resetn};

// Reset of the entire axichacha core
wire total_resetn;
assign total_resetn = !aresetn || !s_axi_aresetn;

// chacha_many core resets if control register resets it or the entire axichacha
// core is resetting
wire chacha_core_resetn_total;
assign chacha_core_resetn_total = total_resetn || chacha_core_resetn;

// Ready for addr if we don't have one
assign s_axi_awready = ~write_addr_avail & ~write_xfer_complete;

// Ready for data if we don't have it
assign s_axi_wready = ~write_data_avail & ~write_xfer_complete;

// Response is valid when transfer is complete
assign s_axi_bvalid = write_xfer_complete & s_axi_bready;

// Response is always OK
assign s_axi_bresp = 0;

// Ready for read address if we have no read address and no transfer is happening
assign s_axi_arready = ~read_addr_avail || (read_addr_avail & ~read_xfer_complete);

// Slave provides data on one clock cycle
assign s_axi_rvalid = read_xfer_complete & read_addr_avail;

// Reads always okay
assign s_axi_rresp = 0;

chacha_many #(.NUMBER_OF_BLOCKS(NUMBER_OF_BLOCKS)) big_chacha (
    .clk(aclk),
    .aresetn(chacha_core_resetn_total),
    .chacha_key(key_reg),
    .chacha_iv(iv_reg),
    .chacha_data_in(data_in),
    .chacha_data_out(data_out),
    .chacha_next_block(next_block),
    .chacha_data_valid(chacha_core_data_valid)
);

// This function determines if an incoming AXI address matches with an internal
// register larger than 32-bits
function automatic axi_addr_matches;
    input [31:0] address, BASE, SIZE;
    begin
        // Ensure address is aligned and between memory region
        if (address % 4 != 0) begin
            axi_addr_matches = 0;
        end else if (address < BASE) begin
            axi_addr_matches = 0;
        end else if (address < BASE + SIZE) begin
            axi_addr_matches = 1;
        end else begin
            axi_addr_matches = 0;
        end
    end
endfunction

// Converts an AXI address of a register larger than 32-bits. Writes
// the values to the most significant bits of the register first.
function automatic integer axi_addr_to_register_msbfirst;
    input [31:0] address, BASE, SIZE;
    begin
        axi_addr_to_register_msbfirst = 8*SIZE - 8*(address - BASE) - 32;
    end
endfunction

// Converts an AXI address of a register larger than 32-bits. Writes
// the values to the least significant bits of the register first.
function automatic integer axi_addr_to_register_lsbfirst;
    input [31:0] address, BASE, SIZE;
    begin
        axi_addr_to_register_lsbfirst = 8*(address - BASE);
    end
endfunction

// Write address handler
always @ (posedge aclk)
begin
    if (total_resetn) begin
        write_addr_avail <= 0;
        write_addr_in <= 0;
    end else begin
        // While we're not in a transfer window
        if (~write_xfer_complete) begin
            write_addr_in <= write_addr_in;
            write_addr_avail <= write_addr_avail;
            // If an address is being written by the master
            if (s_axi_awvalid) begin
                // Save it to a local reg, trimming off the don't care bits
                write_addr_in <= s_axi_awaddr[NUM_ADDRESS_BITS-1:0];
                // Mark that there's an address available for the next transfer
                write_addr_avail <= 1;
            end
        end else begin
            write_addr_avail <= 0;
            write_addr_in <= 0;
        end
    end
end

// Write data handler
always @ (posedge aclk)
begin
    if (total_resetn) begin
        write_data_avail <= 0;
        write_data_in <= 0;
    end else begin
        // While we're not in a transfer window
         if (~write_xfer_complete) begin
            write_data_in <= write_data_in;
            write_data_avail <= write_data_avail;

            // If data is being written by the master
            if (s_axi_wvalid) begin
                // Store it and mark data as available
                write_data_in <= s_axi_wdata;
                write_data_avail <= 1;
            end
        end else begin
            write_data_avail <= 0;
            write_data_in <= 0;
        end
    end
end

// Write transfer process handler
always @ (posedge aclk)
begin
    if (total_resetn) begin
        write_xfer_complete <= 0;
        
        // data_in_reg <= 0;
        key_reg <= 0;
        iv_reg <= 0;
        chacha_core_resetn <= 0;
    end else begin
        // If both address and data is availble to write and there's not an existing transfer
        if (write_addr_avail && write_data_avail && ~write_xfer_complete) begin
            // Start the transfer
            write_xfer_complete <= 1;

            case(write_addr_in)
                ADDR_VERSION: begin
                end
                ADDR_CONTROL: begin
                    chacha_core_resetn <= write_data_in & (1 << CONTROL_BIT_RESET);
                end
                default: begin
                    // Key decoder
                    if (axi_addr_matches(write_addr_in, ADDR_KEY, SIZE_KEY)) begin
                        key_reg[axi_addr_to_register_lsbfirst(write_addr_in, ADDR_KEY, SIZE_KEY) +: 32] <= write_data_in;
                    end

                    // IV decoder
                    if (axi_addr_matches(write_addr_in, ADDR_IV, SIZE_IV)) begin
                        iv_reg[axi_addr_to_register_lsbfirst(write_addr_in, ADDR_IV, SIZE_IV) +: 32] <= write_data_in;
                    end
                end
            endcase
        end else begin
            // Stop the transfer if master marks itself ready for the response
            if (s_axi_rready) begin
                write_xfer_complete <= 0;
            end else begin
                write_xfer_complete <= write_xfer_complete;
            end
        end
    end
end

// Read address channel
always @(posedge aclk)
begin
    if (total_resetn) begin
        read_addr_in <= 0;
        read_addr_avail <= 0;
    end else begin
        read_addr_in <= read_addr_in;
        read_addr_avail <= read_addr_avail;
        
        // If the master has an address and are we not in a transfer
        if (~read_addr_avail && ~read_xfer_complete && s_axi_arvalid) begin
            read_addr_in <= s_axi_araddr[NUM_ADDRESS_BITS-1:0];
            read_addr_avail <= 1;
        end else if (read_xfer_complete) begin
            read_addr_in <= 0;
            read_addr_avail <= 0;
        end
    end
end

// Read transfer handler
always @ (posedge aclk)
begin
    if (total_resetn) begin
        read_xfer_complete <= 0;
        s_axi_rdata <= 32'hdeadbeef;
    end else begin
        read_xfer_complete <= read_xfer_complete;
        if (read_addr_avail) begin
            // Complete the transfer
            read_xfer_complete <= 1;
            case(read_addr_in)
                // Core version
                ADDR_VERSION: begin
                    s_axi_rdata <= VERSION;
                end
                // Control register
                ADDR_CONTROL: begin
                    s_axi_rdata <= control_register_value;
                end
                // Total size of the blocks of data this core operates on
                ADDR_DATA_SIZE: begin
                    s_axi_rdata <= BLOCK_SIZE_BITS / 8;
                end
                default: begin
                    // Key decoder
                    if (axi_addr_matches(read_addr_in, ADDR_KEY, SIZE_KEY)) begin
                        s_axi_rdata <= key_reg[axi_addr_to_register_lsbfirst(read_addr_in, ADDR_KEY, SIZE_KEY) +: 32];
                    end

                    // IV decoder
                    if (axi_addr_matches(read_addr_in, ADDR_IV, SIZE_IV)) begin
                        s_axi_rdata <= iv_reg[axi_addr_to_register_lsbfirst(read_addr_in, ADDR_IV, SIZE_IV) +: 32];
                    end
                end
            endcase
        end else if (s_axi_rready) begin
            // When master is ready, complete the read
            read_xfer_complete <= 0;
        end
    end
end

endmodule 