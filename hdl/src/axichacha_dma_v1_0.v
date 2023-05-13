`timescale 1ns / 1ps

module axichacha_dma_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		parameter integer NUMBER_OF_BLOCKS = 1,
		parameter integer C_S00_AXIS_TDATA_WIDTH  = 32,
		parameter integer C_M00_AXIS_TDATA_WIDTH  = 32,

		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH  = 32,
		parameter integer C_S00_AXI_ADDR_WIDTH  = 32
	)
	(
		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,

		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready,

		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);


	localparam BLOCK_WIDTH = 512;
	localparam BLOCK_SIZE_BITS = NUMBER_OF_BLOCKS * BLOCK_WIDTH;
	localparam BLOCK_SIZE_BYTES = BLOCK_SIZE_BITS / 8;
	localparam WORD_WIDTH_BITS = C_S00_AXIS_TDATA_WIDTH;
	localparam BLOCK_SIZE_WORDS = BLOCK_SIZE_BYTES / (WORD_WIDTH_BITS/8);

	// State defines
	localparam DATA_IN = 2'd0, // Data is being read or written
			   NEXT_BLOCK = 2'd1,
			   WAIT_CRYPT = 2'd2,
			   CRYPT_DONE = 2'd3; // Resetting to the next block to crypt


// Input into axichacha core, comes from the AXI-S slave from DMA
	reg [BLOCK_SIZE_BITS-1:0] data_in_reg;

// When data is valid
	wire data_in_valid;

// Output from axichacha core
	wire [BLOCK_SIZE_BITS-1:0] data_out;

// If high, data out from the core is valid
	wire data_out_valid;

// Reading incoming data from the AXI-S slave
	reg [$clog2(BLOCK_SIZE_WORDS):0] read_pointer;

// Writing data out to the other AXI-S master
	reg [$clog2(BLOCK_SIZE_WORDS):0] write_pointer;

// Current core state
	reg [1:0] current_state;
	reg [1:0] current_state_next;

// When asserted, prepares the chacha core to crypt the next block of data.
	wire next_block;

// Ready to read data as long as we haven't read in an entire block.
	assign s00_axis_tready = read_pointer != BLOCK_SIZE_WORDS && (current_state != NEXT_BLOCK);

// Data is valid when write pointer isn't finished and chacha core is ready
	assign m00_axis_tvalid = (write_pointer != BLOCK_SIZE_WORDS) & data_out_valid && current_state == CRYPT_DONE;

// Data is read from data_out register
	assign m00_axis_tdata = data_out[write_pointer*WORD_WIDTH_BITS +: WORD_WIDTH_BITS];

// Always valid bytes
	assign m00_axis_tstrb = {((C_S00_AXIS_TDATA_WIDTH/8)){1'b1}};

// Transfer is complete when write pointer has read all words
	assign m00_axis_tlast = (write_pointer == BLOCK_SIZE_WORDS-1) & data_out_valid;

// Prepare to crypt the next block when both of the sides are drained
	assign next_block = current_state == NEXT_BLOCK;

	// Controls the central state machine
	always @(*)
	begin
		if (~s00_axis_aresetn) begin
			current_state_next = DATA_IN;
		end else begin
			case (current_state)
				DATA_IN:
					// Move data until both ends are done
					if (read_pointer == BLOCK_SIZE_WORDS) begin
						current_state_next = NEXT_BLOCK;
					end
				NEXT_BLOCK:
					// Bring next_block high to initiate the encryption
					current_state_next = WAIT_CRYPT;
				WAIT_CRYPT:
					if (data_out_valid) begin
						current_state_next = CRYPT_DONE;
					end
				CRYPT_DONE:
					// Wait for master to drain
					if (read_pointer == 0 && write_pointer == BLOCK_SIZE_WORDS) begin
						current_state_next = DATA_IN;
					end
			endcase
		end
	end

	always @(negedge s00_axis_aclk) begin
		if (~s00_axis_aresetn) begin
			current_state <= DATA_IN;
		end else begin
			current_state <= current_state_next;
		end
	end

// AXI-S Slave interface reads data to encrypt over the stream
	always @(posedge s00_axis_aclk)
	begin
		if (~s00_axis_aresetn) begin
			read_pointer <= 0;
			data_in_reg <= 0;
		end else begin
			if (s00_axis_tready & s00_axis_tvalid) begin
				// Read data from AXI-S master
				read_pointer <= read_pointer + 1;
				data_in_reg[read_pointer*WORD_WIDTH_BITS +: WORD_WIDTH_BITS] <= s00_axis_tdata;
			end else if (current_state == WAIT_CRYPT) begin
				read_pointer <= 0;
			end
		end
	end

// AXI-S Master interface writes results of the data over the stream as long as data is valid
// from the chacha core.
	always @(posedge s00_axis_aclk)
	begin
		if (~m00_axis_aresetn) begin
			write_pointer <= BLOCK_SIZE_WORDS;
		end else begin
			// Write data to AXI-S slave
			if (m00_axis_tvalid & m00_axis_tready) begin
				write_pointer <= write_pointer + 1;
			end else if (current_state == NEXT_BLOCK) begin
				write_pointer <= 0;
			end
		end
	end


// AXI ChaCha core
	axichacha # (
		.NUMBER_OF_BLOCKS(NUMBER_OF_BLOCKS),
		.C_S_AXI_DATA_WIDTH(32),
		.C_S_AXI_ADDR_WIDTH(32)
	) axichacha_inst (
		.data_in(data_in_reg),
		.next_block(next_block),
		.data_out(data_out),
		.data_valid(data_out_valid),

		.aclk(s00_axi_aclk),
		.aresetn(s00_axis_aresetn),
		.s_axi_aresetn(s00_axis_aresetn),
		.s_axi_awaddr(s00_axi_awaddr),
		// .s_axi_awprot(s00_axi_awprot),
		.s_axi_awvalid(s00_axi_awvalid),
		.s_axi_awready(s00_axi_awready),
		.s_axi_wdata(s00_axi_wdata),
		// .s_axi_wstrb(s00_axi_wstrb),
		.s_axi_wvalid(s00_axi_wvalid),
		.s_axi_wready(s00_axi_wready),
		.s_axi_bresp(s00_axi_bresp),
		.s_axi_bvalid(s00_axi_bvalid),
		.s_axi_bready(s00_axi_bready),
		.s_axi_araddr(s00_axi_araddr),
		// .s_axi_arprot(s00_axi_arprot),
		.s_axi_arvalid(s00_axi_arvalid),
		.s_axi_arready(s00_axi_arready),
		.s_axi_rdata(s00_axi_rdata),
		.s_axi_rresp(s00_axi_rresp),
		.s_axi_rvalid(s00_axi_rvalid),
		.s_axi_rready(s00_axi_rready)
	);

endmodule
