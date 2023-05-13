`timescale 1ns / 1ps

module main_tb();

localparam C_M00_AXIS_TDATA_WIDTH = 32;
localparam C_S00_AXI_ADDR_WIDTH = 4;
localparam C_S00_AXI_DATA_WIDTH = 32;


// S00_AXIS
reg  s00_axis_aclk = 0;
reg  s00_axis_aresetn = 0;
wire s00_axis_tready;
wire [31:0] s00_axis_tdata;
wire [3:0] s00_axis_tstrb;
wire s00_axis_tlast;
wire s00_axis_tvalid;

// Ports of Axi Master Bus Interface M00_AXIS
reg  m00_axis_aclk = 0;
reg  m00_axis_aresetn = 0;
wire m00_axis_tvalid;
wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata;
wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb;
wire m00_axis_tlast;
wire  m00_axis_tready;

// Ports of Axi Slave Bus Interface S00_AXI
reg  s00_axi_aclk = 0;
reg  s00_axi_aresetn = 0;
reg [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr;
reg [2 : 0] s00_axi_awprot;
reg  s00_axi_awvalid;
wire s00_axi_awready;
reg [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata;
reg [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb;
reg  s00_axi_wvalid;
wire s00_axi_wready;
wire [1 : 0] s00_axi_bresp;
wire s00_axi_bvalid;
reg  s00_axi_bready;
reg [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr;
reg [2 : 0] s00_axi_arprot;
reg  s00_axi_arvalid;
wire s00_axi_arready;
wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata;
wire [1 : 0] s00_axi_rresp;
wire s00_axi_rvalid;
reg  s00_axi_rready;

always #1 s00_axis_aclk = ~s00_axis_aclk;
always #1 m00_axis_aclk = ~m00_axis_aclk;
always #1 s00_axi_aclk = ~s00_axi_aclk;

initial begin
    $dumpfile("main_tb.vcd");
    $dumpvars(0, dut);

    $display("Start generating data...");

    s00_axis_aresetn = 0;
    m00_axis_aresetn = 0;
    @(posedge s00_axis_aclk);
    @(posedge s00_axis_aclk);
    @(posedge s00_axis_aclk);
    s00_axis_aresetn = 1;
    m00_axis_aresetn = 1;
    #1000;
    $display("Finished.");
    $finish;
end

axis_data_generator axis_gen (
    .s00_axis_aclk(s00_axis_aclk),
    .s00_axis_tready(s00_axis_tready),
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid)
);

axis_sink axis_sink_inst (
    .m00_axis_aclk(m00_axis_aclk),
    //.m00_axis_aresetn(m00_axis_aresetn),
    .m00_axis_tvalid(m00_axis_tvalid),
    .m00_axis_tdata(m00_axis_tdata),
    //.m00_axis_tstrb(m00_axis_tstrb),
    .m00_axis_tlast(m00_axis_tlast),
    .m00_axis_tready(m00_axis_tready)
);

axichacha_dma_v1_0 dut (
    .s00_axis_aclk(s00_axis_aclk),
    .s00_axis_aresetn(s00_axis_aresetn),
    .s00_axis_tready(s00_axis_tready),
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tstrb(s00_axis_tstrb),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),

    // Ports of Axi Master Bus Interface M00_AXIS
    .m00_axis_aclk(m00_axis_aclk),
    .m00_axis_aresetn(m00_axis_aresetn),
    .m00_axis_tvalid(m00_axis_tvalid),
    .m00_axis_tdata(m00_axis_tdata),
    .m00_axis_tstrb(m00_axis_tstrb),
    .m00_axis_tlast(m00_axis_tlast),
    .m00_axis_tready(m00_axis_tready),

    // Ports of Axi Slave Bus Interface S00_AXI
    .s00_axi_aclk(s00_axi_aclk),
    .s00_axi_aresetn(s00_axi_aresetn),
    .s00_axi_awaddr(s00_axi_awaddr),
    .s00_axi_awprot(s00_axi_awprot),
    .s00_axi_awvalid(s00_axi_awvalid),
    .s00_axi_awready(s00_axi_awready),
    .s00_axi_wdata(s00_axi_wdata),
    .s00_axi_wstrb(s00_axi_wstrb),
    .s00_axi_wvalid(s00_axi_wvalid),
    .s00_axi_wready(s00_axi_wready),
    .s00_axi_bresp(s00_axi_bresp),
    .s00_axi_bvalid(s00_axi_bvalid),
    .s00_axi_bready(s00_axi_bready),
    .s00_axi_araddr(s00_axi_araddr),
    .s00_axi_arprot(s00_axi_arprot),
    .s00_axi_arvalid(s00_axi_arvalid),
    .s00_axi_arready(s00_axi_arready),
    .s00_axi_rdata(s00_axi_rdata),
    .s00_axi_rresp(s00_axi_rresp),
    .s00_axi_rvalid(s00_axi_rvalid),
    .s00_axi_rready(s00_axi_rready)
);

endmodule