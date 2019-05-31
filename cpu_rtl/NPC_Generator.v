`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB（Embeded System Lab）
// Engineer: Haojun Xia
// Create Date: 2019/03/14 11:21:33
// Design Name: RISCV-Pipline CPU
// Module Name: NPC_Generator
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: Choose Next PC value
//////////////////////////////////////////////////////////////////////////////////
module NPC_Generator(
    input wire [31:0] PCF, PCE, JalrTarget, BranchTarget, JalTarget, Pred_BranchTarget,
    input wire BranchE, JalD, JalrE, BTBF, BTBE, Pred_True, 
    output reg [31:0] PC_In
    );
    always @(*)
    begin
        if(JalrE)
            PC_In <= JalrTarget;
        else if(BranchE)
        begin
            if(Pred_True)
                PC_In <= PCF+4;     //accurately predicted
            else
                PC_In <= BranchTarget;  //mispredicted
        end
        else if(~BranchE & BTBE)    //should not branch but branched
            PC_In <= PCE+4;
        else if(JalD)
            PC_In <= JalTarget;
        else
        begin
            if(BTBF)
                PC_In <= Pred_BranchTarget;
            else
                PC_In <= PCF+4;
        end
    end
endmodule
