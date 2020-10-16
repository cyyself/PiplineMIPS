module d_cache (
    input wire clk, rst,
    //mips core
    input         cpu_data_req     ,
    input         cpu_data_wr      ,
    input  [1 :0] cpu_data_size    ,
    input  [31:0] cpu_data_addr    ,
    input  [31:0] cpu_data_wdata   ,
    output [31:0] cpu_data_rdata   ,
    output        cpu_data_addr_ok ,
    output        cpu_data_data_ok ,

    //axi interface
    output         cache_data_req     ,
    output         cache_data_wr      ,
    output  [1 :0] cache_data_size    ,
    output  [31:0] cache_data_addr    ,
    output  [31:0] cache_data_wdata   ,
    input   [31:0] cache_data_rdata   ,
    input          cache_data_addr_ok ,
    input          cache_data_data_ok 
);
    // //output to mips core
    // assign cpu_inst_rdata   = cache_inst_rdata  ;
    // assign cpu_inst_addr_ok = cache_inst_addr_ok;
    // assign cpu_inst_data_ok = cache_inst_data_ok;

    assign cpu_data_rdata   = cache_data_rdata  ;
    assign cpu_data_addr_ok = cache_data_addr_ok;
    assign cpu_data_data_ok = cache_data_data_ok;

    // //output to axi interface
    // assign cache_inst_req   = cpu_inst_req  ;  
    // assign cache_inst_wr    = cpu_inst_wr   ;  
    // assign cache_inst_size  = cpu_inst_size ;  
    // assign cache_inst_addr  = cpu_inst_addr ;  
    // assign cache_inst_wdata = cpu_inst_wdata;

    assign cache_data_req   = cpu_data_req  ;  
    assign cache_data_wr    = cpu_data_wr   ;  
    assign cache_data_size  = cpu_data_size ;  
    assign cache_data_addr  = cpu_data_addr ;  
    assign cache_data_wdata = cpu_data_wdata; 
endmodule