module d_cache_4_way_random (
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
    reg [WAY - 1 : 0]       cache_dirty[CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH - 1 : 0] cache_tag  [CACHE_DEEPTH - 1 : 0][WAY - 1 : 0];
    reg [31 : 0]            cache_block[CACHE_DEEPTH - 1 : 0][WAY - 1 : 0];

    //随机替换算法
    reg [LOG2_WAY - 1 : 0] random_1;
    always @(posedge clk) begin
        random_1 <= rst ? 0 : random_1 + 1;   //简单使用时钟作为随机数
    end

    wire [LOG2_WAY - 1 : 0] random_2;
    reg [WAY - 1 : 0] lsfr;
    always @(posedge clk) begin //线性反馈移位寄存器LSFR
        if(rst) begin
            lsfr <= 1<<WAY - 1;
        end
        else begin
            lsfr <= {lsfr[WAY - 2 : 0], ^lsfr};
        end
    end
    encoder4x2 encoder1(lsfr, random_2);

    //访问地址分解
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;
    
    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];

    //访问Cache line
    wire [WAY - 1 : 0]       c_valid_way, c_dirty_way;
    wire [TAG_WIDTH - 1 : 0] c_tag_way  [WAY - 1 : 0];
    wire [31 : 0]            c_block_way[WAY - 1 : 0];

    assign c_valid_way = cache_valid[index];
    assign c_dirty_way = cache_dirty[index];
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
    
    //替换的路evict
    reg [LOG2_WAY - 1 : 0] evict;       //要替换的路的编号

    //hit & miss
    wire hit, miss;
    assign hit = |sel_mask;
    assign miss = ~hit;

    //dirty & clean
    wire dirty, clean;
    assign dirty = c_valid_way[evict] & c_dirty_way[evict];
    assign clean = ~dirty;

    //write & read
    wire read, write;
    assign write = cpu_data_wr;
    assign read = ~write;

    //获得命中的cache line的block
    wire [31 : 0] c_block_sel;
    assign c_block_sel = c_block_way[sel];

    //miss & dirty写回内存需要的数据
    wire [TAG_WIDTH - 1 : 0] c_tag_evict;
    wire [31 : 0] c_block_evict;
    
    assign c_tag_evict = c_tag_way[evict];
    assign c_block_evict = c_block_way[evict];

    //------------------debug--------------------
    reg [31:0] read_total, write_total;
    always @(posedge clk) begin
        if(rst) begin
            read_total <= 0;
            write_total <= 0;
        end
        else begin
            if(cpu_data_req & read) begin
                read_total = read_total + 1;
            end
            if(cpu_data_req & write) begin
                write_total = write_total + 1;
            end
        end
    end

    wire read_hit, read_miss_clean, read_miss_dirty, write_hit, write_miss_clean, write_miss_dirty;
    assign read_hit = cpu_data_req & read & hit;
    assign read_miss_clean = cpu_data_req & read & miss & clean;
    assign read_miss_dirty = cpu_data_req & read & miss & dirty;
    assign write_hit = cpu_data_req & write & hit;
    assign write_miss_clean = cpu_data_req & write & miss & clean;
    assign write_miss_dirty = cpu_data_req & write & miss & dirty;
    //------------------debug--------------------

    //FSM
    parameter IDLE = 2'b00, RM = 2'b01, WRM = 2'b10, WM = 2'b11;    //WM: 写回内存；WRM: 先写回内存，再读内存
    reg [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE:   state <= cpu_data_req & read & miss & clean ? RM :
                                 cpu_data_req & read & miss & dirty ? WRM :
                                 cpu_data_req & write & miss & dirty ? WM : IDLE;
                RM:     state <= cache_data_data_ok ? IDLE : RM;
                WM:     state <= cache_data_data_ok ? IDLE : WM;
                WRM:    state <= cache_data_data_ok ? RM : WRM;
            endcase
        end
    end

    wire read_req, write_req;
    reg addr_rcv;
    wire read_finish, write_finish;
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    cache_data_req & cache_data_addr_ok ? 1'b1 :
                    cache_data_data_ok ? 1'b0 : addr_rcv;
    end

    assign read_req = state == RM;
    assign write_req = state == WRM || state == WM;
    assign read_finish = read_req & cache_data_data_ok;
    assign write_finish = write_req & cache_data_data_ok;

    //output to mips core
    assign cpu_data_rdata   = hit ? c_block_sel : cache_data_rdata;
    assign cpu_data_addr_ok = cpu_data_req & (hit | write & clean) | (state==RM || state==WM) & cache_data_addr_ok;
    assign cpu_data_data_ok = cpu_data_req & (hit | write & clean) | (state==RM || state==WM) & cache_data_data_ok;

    //output to axi interface
    assign cache_data_req   = (state!=IDLE) & ~addr_rcv;
    assign cache_data_wr    = write_req ? 1'b1 : 1'b0;
    assign cache_data_size  = write_req ? 2'b10 : cpu_data_size;  //写内存size均为2
    assign cache_data_addr  = write_req ? {c_tag_evict, index, 2'b00} : cpu_data_addr;
    assign cache_data_wdata = c_block_evict; //写内存一定是替换脏块

    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :
                      cpu_data_req ? tag : tag_save;
        index_save <= rst ? 0 :
                      cpu_data_req ? index : index_save;
    end

//获得evict
    always @(posedge cpu_data_req) begin    //不能综合?
        evict <= random_2;
    end

//写入Cache
    wire [31:0] write_cache_data;   //write
    wire [3:0] write_mask;

    //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

    //掩码的使用：位为1的代表需要更新的。
    //位拓展：{8{1'b1}} -> 8'b11111111
    //new_data = old_data & ~mask | write_data & mask
    assign write_cache_data = (hit ? c_block_sel : c_block_evict) & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
                              cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};
    
    wire write_cache_en;
    assign write_cache_en = read_finish | cpu_data_req & write & hit | cpu_data_req & write & miss & clean |write & write_finish;
    
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            for(i=0; i<CACHE_DEEPTH; i=i+1) begin   //刚开始将Cache置为无效, clean
                cache_valid[i][0] <= 0;
                cache_valid[i][1] <= 0;
                cache_valid[i][2] <= 0;
                cache_valid[i][3] <= 0;

                cache_dirty[i][0] <= 0;
                cache_dirty[i][1] <= 0;
                cache_dirty[i][2] <= 0;
                cache_dirty[i][3] <= 0;
            end
        end
        else begin
            if(read_finish) begin //读缺失，访存结束时
                cache_valid[index_save][evict] <= 1'b1;
                cache_dirty[index_save][evict] <= 1'b0;
                cache_tag  [index_save][evict] <= tag_save;
                cache_block[index_save][evict] <= cache_data_rdata;
            end
            else if(cpu_data_req & write & hit) begin //写命中
                cache_dirty[index][sel] <= 1'b1;
                cache_block[index][sel] <= write_cache_data;
            end
            else if(cpu_data_req & write & miss & clean) begin  //写缺失且clean
                cache_valid[index][evict] <= 1'b1;
                cache_dirty[index][evict] <= 1'b1;
                cache_tag  [index][evict] <= tag;
                cache_block[index][evict] <= write_cache_data;
            end
            else if(write & write_finish) begin //写缺失且dirty，需要等写回后再写cache
                cache_valid[index_save][evict] <= 1'b1;
                cache_dirty[index_save][evict] <= 1'b1;
                cache_tag  [index_save][evict] <= tag_save;
                cache_block[index_save][evict] <= write_cache_data;
            end
        end
    end
endmodule

module encoder4x2 (
    input wire [3:0] x, //独热码
    output wire [1:0] y
);
    assign y = {x[3] | x[2], x[3] | x[1]};

endmodule