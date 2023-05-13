`timescale 1ns / 1ps

module axis_data_generator(
    input wire s00_axis_aclk,
    input wire s00_axis_tready,
    output reg [31 : 0] s00_axis_tdata,
    output reg  s00_axis_tlast,
    output reg  s00_axis_tvalid
);

integer counter = 0;

// Send random data down the stream port constantly
initial begin
    s00_axis_tvalid = 0;
    s00_axis_tlast = 0;
    s00_axis_tdata = 32'hdeadbeef;

    @(posedge s00_axis_aclk);
    @(posedge s00_axis_aclk);
    @(posedge s00_axis_aclk);
    @(posedge s00_axis_aclk);
    @(posedge s00_axis_aclk);
    @(negedge s00_axis_aclk);

    while(1) begin

        // 10 alternating between valid and invalid
        for (integer i = 0; i < 10; i = i + 1) begin
            s00_axis_tdata = counter;
            s00_axis_tvalid = 1;
            wait(s00_axis_tready && s00_axis_aclk);
            $display("Sent: %x", s00_axis_tdata);
            counter = counter + 1;

            @(negedge s00_axis_aclk);
            s00_axis_tvalid = 0;
            s00_axis_tdata = 32'hdeadbeef;
            wait(s00_axis_tready && s00_axis_aclk);
            @(negedge s00_axis_aclk);
        end

        // 10 all at once, no invalids in between
        for (integer i = 0; i < 10; i = i + 1) begin
            s00_axis_tdata = counter;
            s00_axis_tvalid = 1;
            wait(s00_axis_tready && s00_axis_aclk);
            $display("Sent: %x", s00_axis_tdata);
            counter = counter + 1;

            @(negedge s00_axis_aclk);
        end
    end
end

endmodule