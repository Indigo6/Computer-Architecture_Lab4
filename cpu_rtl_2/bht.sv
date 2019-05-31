module bht #(
    parameter bht_addr_len = 7
)(
    input  clk, rst,  
    input  BranchE,        
    input  [bht_addr_len-1:0] raddr,     
    input  [bht_addr_len-1:0] waddr,  
    output reg pred_taken      
);

localparam BHT_SIZE     = 1 << bht_addr_len;


reg [1:0] pred_states   [BHT_SIZE]; 

//Predict whether branch or not ( whether take BTB's Predicted_PC or not )
always @ (*) begin                          //read data
    if((pred_states[raddr]==2'b11) || (pred_states[raddr]==2'b10))
        pred_taken = 1'b1;
    else 
        pred_taken = 1'b0;
end

always @ (posedge clk or posedge rst) begin //write data(update BTB)
    if(rst) begin
        for(integer i=0; i<BHT_SIZE; i++) begin
                pred_states[i]=0;
                pred_taken = 0;
        end
    end
    else begin
        if(BranchE)
            case(pred_states[waddr])
            2'b11:
                pred_states[waddr]=2'b11;
            2'b10:
                pred_states[waddr]=2'b11;
            2'b01:
                pred_states[waddr]=2'b11;
            2'b00:
                pred_states[waddr]=2'b01;
            endcase   
        else
            case(pred_states[waddr])
            2'b11:
                pred_states[waddr]=2'b10;
            2'b10:
                pred_states[waddr]=2'b00;
            2'b01:
                pred_states[waddr]=2'b00;
            2'b00:
                pred_states[waddr]=2'b00;
            endcase  
    end
end

endmodule