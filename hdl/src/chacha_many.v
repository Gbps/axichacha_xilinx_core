
// Converts a block of 32-bit little endian words into a block of 32-bit big endian words
module little_to_big_endian #
	(
		parameter integer N = 32
	)
	(
		input  wire [N-1:0] in,
		output reg [N-1:0] out
	);

	function [31 : 0] l2b (input [31 : 0] op);
		begin
			l2b = {op[7 : 0], op[15 : 8], op[23 : 16], op[31 : 24]};
		end
	endfunction

	genvar i;
	generate
		for (i = 0; i < N/32; i = i+1) begin
			always @(in) begin
				out[i*32 +: 32] = l2b(in[i*32 +: 32]);
			end
		end
	endgenerate
endmodule


module chacha_many
#(
    parameter NUMBER_OF_BLOCKS = 1,
    parameter TOTAL_BIT_WIDTH = NUMBER_OF_BLOCKS * 512
)
(
    input wire clk,
    input wire aresetn,
    input wire [255:0] chacha_key,
    input wire [95:0] chacha_iv,
    input wire [TOTAL_BIT_WIDTH-1:0] chacha_data_in,
    input wire chacha_next_block,
    output wire [TOTAL_BIT_WIDTH-1:0] chacha_data_out,
    output wire chacha_data_valid
);

// Blocks are 64 bytes, words are 4 bytes (AXI-S width)
localparam NUMBER_OF_WORDS = NUMBER_OF_BLOCKS * 16;

// 1 if the data is valid to be read and crypt is done
wire [NUMBER_OF_BLOCKS-1:0] chacha_data_out_valids;

// The endianness of the output of the chacha module does not match
// the way Python does it. Flip it here.
wire [TOTAL_BIT_WIDTH-1:0] chacha_data_out_wrongendian;

// If all blocks are valid, the output is valid
assign chacha_data_valid = &chacha_data_out_valids;

// Begins initialization
reg chacha_init;

// Chacha has been initialized by reset
reg chacha_initialized;

reg first_reset;

// Current number of blocks that have been processed
reg [31:0] current_counter;

// Flick chacha init on for one cycle when taken out of reset
always @(posedge clk) begin
    if (~aresetn) begin
        chacha_init <= 0;
        chacha_initialized <= 0;
        current_counter <= 0;
        first_reset <= 1;
    end else begin
        if (chacha_init) begin
            chacha_init <= 0;
            chacha_initialized <= 1;
        end

        // Next block toggles the init signal on the cores
        if (chacha_next_block) begin
            if (first_reset) begin
                first_reset <= 0;
            end else begin
                current_counter <= current_counter + NUMBER_OF_BLOCKS;
            end

            chacha_initialized <= 0;
            chacha_init <= 1;
        end
    end
end

genvar g_i;
generate
    for(g_i = 0; g_i < NUMBER_OF_BLOCKS; g_i = g_i + 1) begin : generate_chacha_modules
        // Truncate the genvar so it doesn't cause addition to result in 65 bits
        localparam [63:0] chacha_ctr_add = g_i;
        // Blocks are reversed for MSB order
        localparam block_i = (g_i);
        chacha_core chacha_g_i(
            .clk(clk),
            .reset_n(aresetn),

            .init(chacha_init),
            .next(1'b0),

            .key(chacha_key),
            .keylen(1'b1), // always 256 bit key
            .iv(chacha_iv),
            .ctr(chacha_ctr_add + current_counter),
            .rounds(5'd20), // always 20 rounds
            .data_in(chacha_data_in[512*block_i +: 512]),

            .ready(),

            .data_out(chacha_data_out[512*block_i +: 512]),
            .data_out_valid(chacha_data_out_valids[block_i])
            );
    end
endgenerate

endmodule
