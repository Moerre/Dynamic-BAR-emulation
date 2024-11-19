//基于Simonrak大佬的智慧 诞生的TLP轮询读取模块

module pcileech_bar_impl_MoerTLP(
    input               rst,
    input               clk,
    input [31:0]        wr_addr,
    input [3:0]         wr_be,
    input [31:0]        wr_data,
    input               wr_valid,
    input  [87:0]       rd_req_ctx,
    input  [31:0]       rd_req_addr,
    input               rd_req_valid,
    input  [31:0]       base_address_register,

    output logic [87:0] rd_rsp_ctx,
    output logic [31:0] rd_rsp_data,
    output logic        rd_rsp_valid
);
    bit [87:0]      drd_req_ctx;
    bit [31:0]      drd_req_addr;
    bit             drd_req_valid;

    bit [31:0]      dwr_addr;
    bit [31:0]      dwr_data;
    bit             dwr_valid;    
	
	wire [19:0] local_addr;//创建新信号 位宽20
	//连接信号local_addr连接为计算后的偏移地址 20'hfffff = 保留后五位
    assign local_addr = ({drd_req_addr[31:24], drd_req_addr[23:16], 
                         drd_req_addr[15:8], drd_req_addr[7:0]} - 
                         base_address_register) & 20'hfffff;


    bit [31:0] rom_0380 [0:1];//创建一个32位宽的信号名为rom_0380  后面的[0:1]说明信号是数组类型 有0-1两个数值

    bit [31:0] rom_0384 [0:1];//同上

    bit [31:0] rom_0000 [0:34];//创建一个32位宽的信号名为rom_0000  后面的[0:34]说明信号是数组类型 有0-34三十五个数值
    bit [5:0] counter_0000;    //创建一个位宽6位计数器，用以计算轮询次数
	//这个计数器位宽要根据数组数量选择，35个数据六个位的二进制数值是可以放下的，如果数值数量更多，就要更改哦

    function rom_addr_check;//rom地址检查函数
        input [19:0] addr;// 输入参数 addr 是一个20位的地址
        begin
            case (addr)// 根据 addr 的值进行选择
                16'h0380, 16'h0384, 16'h0000:// 如果 addr 是这三个值中的任何一个
                    rom_addr_check = 1'b1;// 返回 1，表示地址有效
                default: rom_addr_check = 1'b0;// 否则返回 0，表示地址无效
            endcase
        end
    endfunction

    always_ff @(posedge clk) begin//每当时钟上沿
        if (rst) begin //如果复位
            rd_rsp_valid <= 1'b0; //清除rd_rsp_valid
            counter_0000 <= '0;	 // 将计数器重置为0


            rom_0000[0] <= 32'h00000000;//rom_0000数组 第0个赋值为32'h00000000
            rom_0000[1] <= 32'h00000000;//rom_0000数组 第1个赋值为32'h00000000
            rom_0000[2] <= 32'h00000000;//以此类推
            rom_0000[..] <= 32'h00000000;//省略了哈
            rom_0000[34] <= 32'h00000000;//赋值到数组第35个 对应上面设定的数组数量

            rom_0380[0] <= 32'h00000000;

            rom_0384[0] <= 32'h00000000;//同理
			
	end else begin//如果没有复位 
        drd_req_ctx     <= rd_req_ctx;//
        drd_req_valid   <= rd_req_valid;
        dwr_valid       <= wr_valid;
        drd_req_addr    <= rd_req_addr;
        rd_rsp_ctx      <= drd_req_ctx;
        rd_rsp_valid    <= drd_req_valid;
        dwr_addr        <= wr_addr;
        dwr_data        <= wr_data;

            if (drd_req_valid && rom_addr_check(local_addr)) begin//如果有读写请求且读写地址有效
                case(local_addr)//case判断 local_addr为请求地址
                    16'h0000: begin//地址匹配上的话
					//三元运算：counter_0000 赋值为  a（计算结果）？b ：c
					//如果counter_0000 等于 6'd34，则选择b，否选择c
					//b就是6'd0，也就是counter_0000 赋值为6'd0
					//c就是counter_0000 + 1
                        counter_0000 <= (counter_0000 == 6'd34) ? 6'd0 : counter_0000 + 1;
                        rd_rsp_data <= rom_0000[counter_0000]; //三元运算结束后，赋值rom_0000[counter_0000]
						//这个rom0000中的counter_0000计数器数值就等于读取的次数，从而以此赋值同偏移地址不同值
                    end
			16'h0380: rd_rsp_data <= rom_0380[0];//rom_0380[0]这个数组没有多个数值，所以直接赋值
                    16'h0384: rd_rsp_data <= rom_0384[0];//同理
                    default: rd_rsp_data = 32'h00000000;//没有匹配的地址则默认赋值00000000
                endcase
            end else begin//没有复位，没有读请求以及地址有效的情况下 默认赋值为00000000
                rd_rsp_data <= 32'h00000000;
            end
        end
    end
endmodule
//counter_0000 <= (counter_0000 == 6'd34) 34 different values 6'd0 Resets to after done counter_0000 + 1; go to next value (+1)
