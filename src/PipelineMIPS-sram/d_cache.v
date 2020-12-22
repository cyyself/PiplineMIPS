module d_cache (
    input wire clk, rst,

    input wire        data_en    ,
    input wire [31:0] data_addr  ,
    output wire [31:0] data_rdata ,
    input wire [3:0] data_wen       ,
    input wire [31:0] data_wdata    ,
    output stall               ,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen    ,
    output wire [31:0] data_sram_addr  ,
    output wire [31:0] data_sram_wdata ,
    input wire [31:0] data_sram_rdata
);
    reg one_clk; //read need one clk delay
    always @(posedge clk ) begin
        one_clk <= rst ? 1'b0 :
                   data_en & ~(|data_wen) & ~one_clk? 1'b1 : 1'b0;
    end

    reg [31:0] data_rdata_r;
    always @(posedge clk ) begin
        if(rst) begin
            data_rdata_r <= 0;
        end
        else begin
            data_rdata_r <= data_sram_rdata;
        end
    end

    assign stall = data_en & ~(|data_wen) & ~one_clk;

    assign data_rdata = data_sram_rdata;

    assign data_sram_en = data_en;
    assign data_sram_wen = data_wen;
    assign data_sram_addr = data_addr;
    assign data_sram_wdata = data_wdata;
endmodule