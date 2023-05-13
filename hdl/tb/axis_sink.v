`timescale 1ns / 1ps
module axis_sink(
    input wire m00_axis_aclk,
    output reg m00_axis_tready,
    input wire [31 : 0] m00_axis_tdata,
    input wire  m00_axis_tlast,
    input wire  m00_axis_tvalid
);

// Send random data down the stream port constantly
initial begin
    m00_axis_tready = 1;
    

    @(posedge m00_axis_aclk);
    @(posedge m00_axis_aclk);
    @(posedge m00_axis_aclk);
    @(posedge m00_axis_aclk);
    @(posedge m00_axis_aclk);

    while(1) begin

        m00_axis_tready = 1;

        // Receive words in a loop
        for (integer i = 0; i < 10; i = i + 1) begin
            wait (m00_axis_tvalid && m00_axis_aclk);
            @(negedge m00_axis_aclk);
            if (m00_axis_tvalid) begin
                $display("Got: %x", m00_axis_tdata);
            end
        end

        // Add some fake backpressure.
        m00_axis_tready = 0;

        for (integer i = 0; i < 10; i = i + 1) begin
            @(negedge m00_axis_aclk);
        end
    end
end

endmodule