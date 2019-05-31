`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLABï¼ˆEmbeded System Labï¼?
// Engineer: Haojun Xia
// Create Date: 2019/03/14 11:21:33
// Design Name: RISCV-Pipline CPU
// Module Name: NPC_Generator
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: Choose Next PC value
//////////////////////////////////////////////////////////////////////////////////
module NPC_Generator(
    input wire [31:0] PCF, PCE, JalrTarget, BranchTarget, JalTarget, BTB_Target,
    input wire BranchE, JalD, JalrE, BTBF, BHTF, BTBE, BHTE, Pred_True,
    output reg [31:0] PC_In
    );
    always @(*)begin
        if(JalrE)
            PC_In <= JalrTarget;
        else if(BranchE) begin
            if(Pred_True)
                PC_In <= PCF+4;
            else
                PC_In <= BranchTarget;
        end
        else if( (~BranchE) & (BTBE & BHTE))
            PC_In <= PCE+4;
        else if(JalD)
            PC_In <= JalTarget;
        else begin
            if(BTBF & BHTF)
                PC_In <= BTB_Target;
            else
                PC_In <= PCF+4;
        end
    end
endmodule
