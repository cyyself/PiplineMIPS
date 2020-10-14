// 结构
//           ---------------------------------------    mycpu_top.v
//        |   -------------------------    mips core|
//        |   |        data_path       |            |
//        |   -------------------------             |
//        |        | sram       | sram              |
//        |      ----           ----                |
//        |     |    |         |    |               |
//        |      ----           ----                |
//        |        | sram-like    | sram-like       |
//           ---------------------------------------
//                 | sram-like    | sram-like
//           ---------------------------------------
//        |    								cache    |
//        |    								         |
//           ---------------------------------------
//                 | sram-like    | sram-like
//           ---------------------------------------
//        |    			cpu_axi_interface(longsoon)  |
//        |    								         |
//           ---------------------------------------
//          			        | axi

module mycpu_top(
    input [5:0] ext_int,   //high active  //input

    input wire aclk,    
    input wire aresetn,   //low active

    output wire[3:0] arid,
    output wire[31:0] araddr,
    output wire[7:0] arlen,
    output wire[2:0] arsize,
    output wire[1:0] arburst,
    output wire[1:0] arlock,
    output wire[3:0] arcache,
    output wire[2:0] arprot,
    output wire arvalid,
    input wire arready,
                
    input wire[3:0] rid,
    input wire[31:0] rdata,
    input wire[1:0] rresp,
    input wire rlast,
    input wire rvalid,
    output wire rready, 
               
    output wire[3:0] awid,
    output wire[31:0] awaddr,
    output wire[7:0] awlen,
    output wire[2:0] awsize,
    output wire[1:0] awburst,
    output wire[1:0] awlock,
    output wire[3:0] awcache,
    output wire[2:0] awprot,
    output wire awvalid,
    input wire awready,
    
    output wire[3:0] wid,
    output wire[31:0] wdata,
    output wire[3:0] wstrb,
    output wire wlast,
    output wire wvalid,
    input wire wready,
    
    input wire[3:0] bid,
    input wire[1:0] bresp,
    input bvalid,
    output bready,

    //debug interface
    output wire[31:0] debug_wb_pc,
    output wire[3:0] debug_wb_rf_wen,
    output wire[4:0] debug_wb_rf_wnum,
    output wire[31:0] debug_wb_rf_wdata
);
wire clk, rst;
assign clk = aclk;
assign rst = ~aresetn;

wire        inst_req  ;
wire [31:0] inst_addr ;
wire        inst_wr   ;
wire [1:0]  inst_size ;
wire [31:0] inst_wdata;
wire [31:0] inst_rdata;
wire        inst_addr_ok;
wire        inst_data_ok;

wire        data_req  ;
wire [31:0] data_addr ;
wire        data_wr   ;
wire [1:0]  data_size ;
wire [31:0] data_wdata;
wire [31:0] data_rdata;
wire        data_addr_ok;
wire        data_data_ok;

mips_core mips_core(
    .clk(clk), .rst(rst),
    .ext_int(ext_int),

    .inst_req     (inst_req  ),
    .inst_wr      (inst_wr   ),
    .inst_addr    (inst_addr ),
    .inst_size    (inst_size ),
    .inst_wdata   (inst_wdata),
    .inst_rdata   (inst_rdata),
    .inst_addr_ok (inst_addr_ok),
    .inst_data_ok (inst_data_ok),

    .data_req     (data_req  ),
    .data_wr      (data_wr   ),
    .data_addr    (data_addr ),
    .data_wdata   (data_wdata),
    .data_size    (data_size ),
    .data_rdata   (data_rdata),
    .data_addr_ok (data_addr_ok),
    .data_data_ok (data_data_ok),

    .debug_wb_pc       (debug_wb_pc       ),  
    .debug_wb_rf_wen   (debug_wb_rf_wen   ),  
    .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),  
    .debug_wb_rf_wdata (debug_wb_rf_wdata )  
);

//cache

//

cpu_axi_interface cpu_axi_interface(
    .clk(clk),
    .resetn(~rst),

    .inst_req       (inst_req  ),
    .inst_wr        (inst_wr   ),
    .inst_size      (inst_size ),
    .inst_addr      (inst_addr ),
    .inst_wdata     (inst_wdata),
    .inst_rdata     (inst_rdata),
    .inst_addr_ok   (inst_addr_ok),
    .inst_data_ok   (inst_data_ok),

    .data_req       (data_req  ),
    .data_wr        (data_wr   ),
    .data_size      (data_size ),
    .data_addr      (data_addr ),
    .data_wdata     (data_wdata ),
    .data_rdata     (data_rdata),
    .data_addr_ok   (data_addr_ok),
    .data_data_ok   (data_data_ok),

    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

endmodule