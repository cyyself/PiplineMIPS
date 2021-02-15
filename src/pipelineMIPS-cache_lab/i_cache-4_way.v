module i_cache_4_way (
    input wire clk, rst,
    //mips core
    input         cpu_inst_req     ,
    input         cpu_inst_wr      ,
    input  [1 :0] cpu_inst_size    ,
    input  [31:0] cpu_inst_addr    ,
    input  [31:0] cpu_inst_wdata   ,
    output [31:0] cpu_inst_rdata   ,
    output        cpu_inst_addr_ok ,
    output        cpu_inst_data_ok ,

    //axi interface
    output         cache_inst_req     ,
    output         cache_inst_wr      ,
    output  [1 :0] cache_inst_size    ,
    output  [31:0] cache_inst_addr    ,
    output  [31:0] cache_inst_wdata   ,
    input   [31:0] cache_inst_rdata   ,
    input          cache_inst_addr_ok ,
    input          cache_inst_data_ok 
);
    //value of the ceiling of the log base 2.
    function integer clog2;
    input integer value;
    begin
        value = value-1;
        for (clog2=0; value>0; clog2=clog2+1)
            value = value>>1;
    end
    endfunction

    //Cache配置
    parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2, WAY = 4;
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    localparam LOG2_WAY = clog2(WAY);
    
    //Cache存储单元
    reg [WAY - 1 : 0]       cache_valid[CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH - 1 : 0] cache_tag  [CACHE_DEEPTH - 1 : 0][WAY - 1 : 0];
    reg [31 : 0]            cache_block[CACHE_DEEPTH - 1 : 0][WAY - 1 : 0];
    reg [WAY - 2 : 0]       LRU_lines  [CACHE_DEEPTH - 1 : 0];  //4路组相联每行需要3bit

    //访问地址分解
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;
    
    assign offset = cpu_inst_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_inst_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_inst_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];

    //访问Cache line
    wire [WAY - 1 : 0]       c_valid_way;
    wire [TAG_WIDTH - 1 : 0] c_tag_way  [WAY - 1 : 0];
    wire [31 : 0]            c_block_way[WAY - 1 : 0];
    wire [WAY-2 : 0]         LRU_bits;

    assign c_valid_way = cache_valid[index];
    assign LRU_bits    = LRU_lines  [index];
    assign c_tag_way[0]   = cache_tag[index][0];
    assign c_tag_way[1]   = cache_tag[index][1];
    assign c_tag_way[2]   = cache_tag[index][2];
    assign c_tag_way[3]   = cache_tag[index][3];
    assign c_block_way[0] = cache_block[index][0];
    assign c_block_way[1] = cache_block[index][1];
    assign c_block_way[2] = cache_block[index][2];
    assign c_block_way[3] = cache_block[index][3];

    //判断是否命中
    wire [WAY - 1 : 0] sel_mask;    //命中的路(独热码)
    wire [LOG2_WAY - 1 : 0] sel; //命中的路的编号
    assign sel_mask[0] = c_valid_way[0] & !(c_tag_way[0]^ tag); 
    assign sel_mask[1] = c_valid_way[1] & !(c_tag_way[1]^ tag); 
    assign sel_mask[2] = c_valid_way[2] & !(c_tag_way[2]^ tag); 
    assign sel_mask[3] = c_valid_way[3] & !(c_tag_way[3]^ tag); 
    encoder4x2 encoder0(sel_mask, sel);

    //获得替换的路evict
    wire [LOG2_WAY - 1 : 0] evict; //要替换的路的编号
    assign evict = {LRU_bits[0], ~LRU_bits[0] ? LRU_bits[1] : LRU_bits[2]};

    //hit & miss
    wire hit, miss;
    assign hit = |sel_mask;
    assign miss = ~hit;

    //获得命中的cache line的block
    wire [31 : 0] c_block_sel;
    assign c_block_sel = c_block_way[sel];

    //FSM
    parameter IDLE = 2'b00, RM = 2'b01; // i cache只有read
    reg [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE:   state <= cpu_inst_req & miss ? RM : IDLE;
                RM:     state <= cache_inst_data_ok ? IDLE : RM;
            endcase
        end
    end

    //读内存
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
    wire read_req;      //一次完整的读事务，从发出读请求到结束
    reg addr_rcv;       //地址接收成功(addr_ok)后到结束
    wire read_finish;   //数据接收成功(data_ok)，即读请求结束
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    cache_inst_req & cache_inst_addr_ok ? 1'b1 :
                    read_finish ? 1'b0 : addr_rcv;
    end
    assign read_req = state==RM;
    assign read_finish = cache_inst_data_ok;

    //output to mips core
    assign cpu_inst_rdata   = hit ? c_block_sel : cache_inst_rdata;
    assign cpu_inst_addr_ok = cpu_inst_req & hit | cache_inst_req & cache_inst_addr_ok;
    assign cpu_inst_data_ok = cpu_inst_req & hit | cache_inst_data_ok;

    //output to axi interface
    assign cache_inst_req   = read_req & ~addr_rcv;
    assign cache_inst_wr    = cpu_inst_wr;
    assign cache_inst_size  = cpu_inst_size;
    assign cache_inst_addr  = cpu_inst_addr;
    assign cache_inst_wdata = cpu_inst_wdata;

    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :
                      cpu_inst_req ? tag : tag_save;
        index_save <= rst ? 0 :
                      cpu_inst_req ? index : index_save;
    end

//LRU更新
    wire [LOG2_WAY-1 : 0] LRU_visit;  //记录最近访问了哪路，用于更新LRU 

    assign LRU_visit = hit ? sel : evict;
    integer j;
    always @(posedge clk) begin
        if(rst) begin
            for(j=0; j<CACHE_DEEPTH; j=j+1) begin
                LRU_lines[j] <= 0;
            end
        end
        else begin
            if(hit) begin
                LRU_lines[index][0] <= ~LRU_visit[1];
                LRU_lines[index][1] <= ~LRU_visit[1] ? ~LRU_visit[0] : LRU_lines[index][1];
                LRU_lines[index][2] <=  LRU_visit[1] ? ~LRU_visit[0] : LRU_lines[index][2];
            end
            else if(read_finish) begin
                LRU_lines[index_save][0] <= ~LRU_visit[1];
                LRU_lines[index_save][1] <= ~LRU_visit[1] ? ~LRU_visit[0] : LRU_lines[index][1];
                LRU_lines[index_save][2] <=  LRU_visit[1] ? ~LRU_visit[0] : LRU_lines[index][2];
            end
        end
    end

//写入Cache
    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
                cache_valid[t] <= 0;
            end
        end
        else begin
            if(read_finish) begin //读缺失，访存结束时
                cache_valid[index_save][evict] <= 1'b1;             //将Cache line置为有效
                cache_tag  [index_save][evict] <= tag_save;
                cache_block[index_save][evict] <= cache_inst_rdata; //写入Cache line
            end
        end
    end
endmodule