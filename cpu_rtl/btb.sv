module btb(
    input  clk, rst,
    output reg btb_hit,         //whether entry of raddr(PCF) exists
    input  [31:0] raddr,        //PCF
    output reg [31:0] rd_data,  //Predicted target     
    input  [1:0]  web,          //BTB_Update type
    input  [31:0] waddr,        //PCE(Update addr)
    input  [31:0] wr_data       //BrcPC
);

localparam btb_addr_len = 7;
localparam BTB_SIZE     = 1 << btb_addr_len;

wire [btb_addr_len-1:0]   rbtb_addr;    // read addr?
wire [31:btb_addr_len ]   rtag_addr;    // read tag
wire [btb_addr_len-1:0]   wbtb_addr;    // write addr
wire [31:btb_addr_len ]   wtag_addr;    // write tag


reg [31:0           ] pred_pc   [BTB_SIZE]; 
reg [31:btb_addr_len] btb_tags  [BTB_SIZE]; 
reg valid [BTB_SIZE];

assign {rtag_addr,rbtb_addr} = raddr;       // analysis into 2 parts
assign {wtag_addr,wbtb_addr} = waddr;       // ~

always @ (*) begin                          //read data
    if( (valid[rbtb_addr]==1'b1) && (btb_tags[rbtb_addr] == rtag_addr) ) begin
        rd_data = pred_pc[rbtb_addr];  
        btb_hit = 1'b1;
    end
    else begin
        rd_data = raddr+4;
        btb_hit = 1'b0;
    end
end

always @ (posedge clk or posedge rst) begin //write data(update BTB)
    if(rst) begin
        for(integer i=0; i<BTB_SIZE; i++) begin
                btb_tags[i]=0;
                valid[i]=0;
                pred_pc[i]=0;
                btb_hit = 0;
                rd_data = 0;
        end
    end
    else
        case(web)
        2'b01:  begin   //need to update branch target 
                pred_pc[wbtb_addr] = wr_data;
                end
        2'b10:  begin   //need to add entry
                pred_pc[wbtb_addr] = wr_data;
                btb_tags[wbtb_addr] = wtag_addr;
                valid[wbtb_addr] = 1'b1;
                end
        2'b11:  begin   //need to remove entry(invalidate entry)
                valid[wbtb_addr] = 1'b0;
                end   
        endcase
end

endmodule