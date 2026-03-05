class fifo_driver;

  virtual fifo_if vif;
  mailbox #(fifo_transaction) gen2drv;  //from generator
  mailbox #(logic [63:0])     drv2scb; // written data to scoreboard

  function new(virtual fifo_if v,
               mailbox #(fifo_transaction) g,
               mailbox #(logic [63:0]) d);
    vif = v;
    gen2drv = g;
    drv2scb = d;
  endfunction

  task reset();
    $display("[DRV] Reset start");
    @(posedge vif.wrclk);
    vif.wrst_n  <= 0;   
    vif.rrst_n  <= 0;
    vif.wr_en   <= 0;
    vif.rd_en   <= 0;
    vif.data_in <= 0;
    
    repeat(5) @(posedge vif.wrclk);
    repeat(5) @(posedge vif.rdclk);
    
    vif.wrst_n  <= 1;   
    vif.rrst_n  <= 1;
    
    @(posedge vif.wrclk);
    $display("[DRV] Reset done\n");
  endtask

  // drive each transaction one by one
  task run();
    fifo_transaction txn;
    forever begin

      gen2drv.get(txn); // wait for transaction from generator
      txn.print("DRV");

      // drive write on write clock
      @(posedge vif.wrclk);
      vif.wr_en   <= txn.wr_en;
      vif.data_in <= txn.data_in;

      // if write actually landed, tell scoreboard
      @(posedge vif.wrclk);
      if (vif.wr_en && !vif.fifo_full)
        drv2scb.put(vif.data_in);
      vif.wr_en <= 0;

      // drive read on read clock
      @(posedge vif.rdclk);
      vif.rd_en <= txn.rd_en;
      vif.rd_en <= 0;

    end
  endtask

endclass
