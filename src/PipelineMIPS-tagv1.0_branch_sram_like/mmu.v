module mmu (
    input wire [31:0] inst_vaddr,
    output wire [31:0] inst_paddr,
    input wire [31:0] data_vaddr,
    output wire [31:0] data_paddr
);
    assign inst_paddr = (inst_vaddr[31:29] == 3'b100 || inst_vaddr[31:29] == 3'b101) ?
           {3'b0, inst_vaddr[28:0]} : inst_vaddr;
    assign data_paddr = (data_vaddr[31:29] == 3'b100 || data_vaddr[31:29] == 3'b101) ?
           {3'b0, data_vaddr[28:0]} : data_vaddr;
endmodule