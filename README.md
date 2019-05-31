# 分支预测 实验报告

<font color = orange size=5px>目录下 cpu_rtl 文件夹是只有 BTB 的代码，cpu_rtl2 文件夹是 BTB+BHT 的代码</font>

## 分支预测 实现过程

### 1. BTB

#### 1.1 预测

+ > 当前指令的地位用用于寻址，对比比指令的高高位和buffer中是否相等并且有效位为

  { rbtb_tag,  rbtb_addr } = PCF，其中 len(rbtb_addr) = btb_addr_len，而 BTB_SIZE = 1 << btb_addr_len，即 PC 的低位 PC[btb_addr_len-1 : 0] 作为地址，高位作为 tag。

+ >buffer 放在取指阶段，buffer内容读取一一个周期内可以完成

  通过个人的理论学习以及实验检验，BTB读取不应该花一个时钟周期，否则 PCF+4 还是会进入 IF 段。如果命中，PC_In 应该立即变为 Prediced_PC，确保立即执行跳转后（预测跳转）的指令

+ NPC

  ```verilog
  else
  begin
      if(BTBF)
          PC_In <= Pred_BranchTarget;
      else
          PC_In <= PCF+4;
  end
  ```

#### 1.2 EX 阶段，以及 BTB 的更新

- RV32Core.v 中，代表 EX 阶段检验是否预测正确

  ```verilog
  //PPCE: Predicted branch PC at EX stage
  //BTB.rdata -> PPCF -> PPCD -> PPCE
  //BTB.btb_hit -> BTBF ->BTBD ->BTBE
  assign Pred_True = (PPCE==BrNPC)? 1: 0;
  assign BTB_Update = BranchE ? (BTBE ? (Pred_True ? 2'b00 : 2'b01) : 2'b10) : (BTBE ? 2'b11 : 2'b00);
  //01 need to update branch target
  //10 need to add entry
  //11 need to remove entry
  ```

- HarzardUnit，根据是否预测错（未预测到跳转，或地址正确，或者预测了跳转但其实不跳转）产生 FlushD/FlushE 信号

  ```verilog
  else if(BranchE) begin
      if(BTB_Update==2'b00)   //Predicted branch accurately
          {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0000000000;
      else                    //Should branch but not predicted or predicted wrong target
          {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0001010000;
  end
  else if(BTBE) begin
      if(BTB_Update==2'b11)   //Should not branch but predicted
          {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0001010000;
      else 
          {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0000000000;
  end
  ```

- NPC 模块

  ```verilog
  else if(BranchE)
  begin
      if(Pred_True)
          PC_In <= PCF+4;     	//accurately predicted
      else
          PC_In <= BranchTarget;  //mispredicted
  end
  else if(~BranchE & BTBE)    	//should not branch but branched
      PC_In <= PCE+4;
  ```

+ btb.sv 中，代表根据 EX 阶段的检验结果更新

  ```verilog
  //web = BTB_Update
  //{ wbtb_tag,  wbtb_addr } = PCE
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
  ```

### 2. BTB + BHT

#### 2.1 预测

+ BHT_SIZE = 1 << bht_addr_len，bht_addr_len 是个全局参数，在 RV32Core.v 中赋值，并在调用 bht.sv 时传参

+ BHT.sv：预测是否跳转，即产生 BHTF 信号

  + 同理，这里也是不应该花上一个周期的，必须马上出来

  ```verilog
  //raddr = PCF[bht_addr_len-1:0]
  always @ (*) begin                          //read data
      if((pred_states[raddr]==2'b11) || (pred_states[raddr]==2'b10))
          pred_taken = 1'b1;
      else 
          pred_taken = 1'b0;
  end
  ```

+ RV32Core.v：根据 BTBF 和 BHTF 信号产生预测地址 FPPCF(Final Predicted branch PC at IF stage)

  ```verilog
  assign FPPCF = BHTF? (BTBF? PPCF : (PCF+4)) : (PCF+4);
  ```

+ NPC

  ```verilog
  else begin
      if(BTBF & BHTF)
          PC_In <= BTB_Target;
      else
          PC_In <= PCF+4;
  end
  ```

#### 2.2 EX阶段，以及 BTB、BHT 的更新

- RV32Core.v 中，代表 EX 阶段检验是否预测正确

  **BTB_Update 的判断和没有 BHT 时略有不同，<font color=red>因为 BTB = 1, BHT = 1, 但是不跳转时 BTB 的入口不应该删除（对应二层循环不删除内层循环 brnach 指令的跳转入口）</font>**

  ```verilog
  assign BTB_True = (PPCE==BrNPC)? 1: 0;
  assign BTB_Update = BranchE ? (BTBE ? (BTB_True ? 2'b00 : 2'b01) : 2'b10) : (BTBE ? (BHTE? 2'b00 : 2'b11): 2'b00); //和只有 BTB 时不一样
  
  assign Pred_True = (FPPCE==BrNPC) ? 1'b1 : 1'b0;
  ```

- HarzardUnit，根据是否预测错（未预测到跳转，或地址正确，或者预测了跳转但其实不跳转）产生 FlushD/FlushE 信号

  ```verilog
  else if(BranchE) begin
      if(Pred_True)
      {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0000000000;	//Predicted accurately
      else
      {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0001010000;	//mispredicted
  end 
  else if((~BranchE) & BHTE) begin
      if(BTBE)
      {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0001010000;	//Should not branch but predicted
      else
      {StallF,FlushF,StallD,FlushD,StallE,FlushE,StallM,FlushM,StallW,FlushW} <= 10'b0000000000;	//Should not branch and BHT predicted, but BTB not hit, still needn't flush
  end
  ```

- NPC 模块

  ```verilog
  else if(BranchE) begin
      if(Pred_True)	//Predicted accurately
          PC_In <= PCF+4;
      else			//mispredicted
          PC_In <= BranchTarget;
  end
  else if( (~BranchE) & (BTBE & BHTE))
      PC_In <= PCE+4;	//Should not branch but predicted
  ```

- btb.sv 中，代表根据 EX 阶段的检验结果更新（不变，**变化在判断 BTB_Update 中体现**）

- bht.sv中，代表根据 EX 阶段的检验结果更新状态机

  ```verilog
  //waddr = PCE[bht_addr_len-1:0]
  else begin
      if(BranchE)
          case(pred_states[waddr])	//BHTE = pred_states[waddr]
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
  ```

## 实验结果

### 0. 如何生成代码

使用 lab3 提供的 asm2verilogrom.py 脚本，输入 `python 
asm2verilogrom.py bht.S InstructionRAM.sv`，然后打开生成的 InstructionRAM.sv，将其中的指令初始代码复制到我们的 InstructionRam.v 中

即复制如下的代码

```verilog
initial begin
    ram_cell[       0] = 32'h00000293;
	···
end
```

现在初始化的代码是 bht2.s 的，3*1000 重循环

### 1. 统计预测结果的代码

```verilog
reg [10:0] branch_time,flush_time,true_time;
always @ (posedge CPU_CLK or posedge CPU_RST) begin
 if(CPU_RST) begin
    branch_time = 0;
    flush_time = 0;
    true_time = 0;
 end
 else begin
    if(BranchTypeE != 3'b000)
        branch_time = branch_time + 1;
    if(FlushD) 
        flush_time = flush_time + 1;
    if((BranchTypeE != 3'b000) & (~FlushD))
        true_time = true_time + 1;
 end
end
```

### 2. 统计结果

+ 16ns 的初始化时间（已减去），Time per Cycle：4ns
+ 预测的错误次数 Wrong_Times 越大，则花费的时钟周期数 Cylcles 越大，CPI 也越大

#### 2.1 btb.s

共 304 条指令

|      | Cycles | Cycle_Diff | Right_Times | Wrong_Times | CPI  | Speedup |
| :--: | :----: | :--------: | :---------: | :---------: | :--: | :-----: |
| RAW  |  511   |     \      |      0      |     100     | 1.68 |    \    |
| BTB  |  315   |    196     |     98      |      2      | 1.04 |  1.62   |

+ 理论分析：btb.s 只有一层 100 次条件跳转，所以 BTB 只有两次预测错误

#### 2.2 bht.s

共 335 条指令

|         | Cycles | Cycle_Diff | Right_Times | Wrong_Times | CPI  | Speedup |
| :-----: | :----: | :--------: | :---------: | :---------: | :--: | :-----: |
|   RAW   |  537   |     \      |      0      |     110     | 1.60 |    \    |
|   BTB   |  383   |    154     |     88      |     22      | 1.14 |  1.40   |
| BTB+BHT |  371   |    166     |     95      |     15      | 1.11 |  1.45   |

+ BTB 到 BTB+BHT 的加速比为 1.03

+ 理论分析：bht.s 有两层循环，所以 BTB+BHT 比 BTB 更优（可以在从外层循环重新进入内层循环、再次遇到内层条件跳转指令的时候，再次预测跳转正确）。

  **但是因为外层循环少，只有 10 次，所以 “BTB 到 BTB+BHT 的区别” 不是很明显。**

#### 2.3 bht2.s（自己写的）

**<font color = red>上一节(2.2) 的理论分析得到了证明</font>**

```ASM
.org 0x0
 	.global _start
_start:
    addi t0, zero, 0
    addi t1, zero, 0
    addi t2, zero, 0
    addi t3, zero, 2
    addi t4, zero, 1000
for_out: 
    addi t2, t2, 1 
for_in:
    add  t1, t1, t0
    addi t0, t0, 1
    bne  t0, t3, for_in
    addi t0, zero, 0
    bne  t2, t4, for_out
    addi t1, t1, 1
```

|         | Cycles | Right_Times | Wrong_Times | CPI_BHT |
| :-----: | :----: | :---------: | :---------: | :-----: |
|   BTB   | 13014  |     998     |    2002     |    \    |
| BTB+BHT | 11016  |    1997     |    1003     |  1.18   |

## PPT 真值表的补全

### 1. BTB

| **BTB** | **REAL** | **NPC_PRED** | **flush** | **NPC_REAL** | **BTB update** |
| ------- | -------- | ------------ | --------- | ------------ | -------------- |
| **Y**   | **Y**    | **BUF**      | **N**     | **BUF**      | **N**          |
| **Y**   | **N**    | **BUF**      | **Y**     | **PC_EX+4**  | **Y**          |
| **N**   | **Y**    | **PC_IF+4**  | **Y**     | **BT_EX**    | **Y**          |
| **N**   | **N**    | **PC_IF+4**  | **N**     | **PC_EX+4**  | **N**          |

### 2. BHT

| **BTB** | **BHT** | **REAL** | **NPC_PRED** | **flush** | **NPC_REAL** | **BTB update** |
| ------- | ------- | -------- | ------------ | --------- | ------------ | -------------- |
| **Y**   | **Y**   | **Y**    | **BUF**      | **N**     | **BUF**      | **N**          |
| **Y**   | **Y**   | **N**    | **BUF**      | **Y**     | **PC_EX+4**  | **N**          |
| **Y**   | **N**   | **Y**    | **PC_IF+4**  | **Y**     | **BUF**      | **N**          |
| **Y**   | **N**   | **N**    | **PC_IF+4**  | **N**     | **PC_EX+4**  | **Y**          |
| **N**   | **Y**   | **Y**    | **PC_IF+4**  | **Y**     | **BrNPC**    | **Y**          |
| **N**   | **Y**   | **N**    | **PC_IF+4**  | **N**     | **PC_EX+4**  | **N**          |
| **N**   | **N**   | **Y**    | **PC_IF+4**  | **Y**     | **BrNPC**    | **Y**          |
| **N**   | **N**   | **N**    | **PC_IF+4**  | **N**     | **PC_EX+4**  | **N**          |