class fifo_transaction;
  logic [63:0] data_in;   
  logic [63:0] data_out;  
  bit          wr_en;     
  bit          rd_en;     

  function void print(string tag);
    $display("[%0t][%s] wr=%0b rd=%0b data_in=%0h data_out=%0h",
             $time, tag, wr_en, rd_en, data_in, data_out);
  endfunction

endclass
