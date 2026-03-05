interface fifo_if (input logic wrclk, input logic rdclk);

  logic        wrst_n;     
  logic        rrst_n;     
  logic        wr_en;      
  logic        rd_en;      
  logic [63:0] data_in;    
  logic [63:0] data_out;   
  logic        fifo_full;  
  logic        fifo_empty; 
  logic [3:0]  b_rptr_mon; 
  
endinterface
