`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB
// Engineer: Xuan Wang (wgg@mail.ustc.edu.cn)
// 
// Create Date: 2019/02/08 16:29:41
// Design Name: RISCV-Pipline CPU
// Module Name: InstructionRamWrapper
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: a Verilog-based ram which can be systhesis as BRAM
// 
//////////////////////////////////////////////////////////////////////////////////


module InstructionRam(
    input  clk,
    input  web,
    input  [31:2] addra, addrb,
    input  [31:0] dinb,
    output reg [31:0] douta, doutb
);
initial begin douta=0; doutb=0; end

wire addra_valid = ( addra[31:14]==18'h0 );
wire addrb_valid = ( addrb[31:14]==18'h0 );
wire [11:0] addral = addra[13:2];
wire [11:0] addrbl = addrb[13:2];

reg [31:0] ram_cell [0:4095];

initial begin
    ram_cell[       0] = 32'h00000293;
    ram_cell[       1] = 32'h00000313;
    ram_cell[       2] = 32'h00000393;
    ram_cell[       3] = 32'h00200e13;
    ram_cell[       4] = 32'h3e800e93;
    ram_cell[       5] = 32'h00138393;
    ram_cell[       6] = 32'h00530333;
    ram_cell[       7] = 32'h00128293;
    ram_cell[       8] = 32'hffc29ce3;
    ram_cell[       9] = 32'h00000293;
    ram_cell[      10] = 32'hffd396e3;
    ram_cell[      11] = 32'h00130313;

end

always @ (posedge clk)
    douta <= addra_valid ? ram_cell[addral] : 0;
    
always @ (posedge clk)
    doutb <= addrb_valid ? ram_cell[addrbl] : 0;

always @ (posedge clk)
    if(web & addrb_valid) 
        ram_cell[addrbl] <= dinb;

endmodule