class fifo_monitor;

  virtual fifo_if vif;
  mailbox #(fifo_transaction) mon2scb; // send to scoreboard

  function new(virtual fifo_if v, mailbox #(fifo_transaction) m);
    vif     = v;
    mon2scb = m;
  endfunction

  task run();
    fifo_transaction txn;
    logic [3:0] prev_rptr  = 0; // last seen value of b_rptr
    logic       prev_empty = 1; // last seen fifo_empty
    logic       prev_rd_en = 0; // last seen rd_en

    // wait for reset to finish
    while (!vif.rrst_n) @(posedge vif.rdclk);
    repeat(2) @(posedge vif.rdclk); #2;
    $display("[MON] Started\n");

    forever begin
      @(posedge vif.rdclk); #2;

      // b_rptr changed = DUT read one value
      if (vif.b_rptr_mon !== prev_rptr) begin

        // skip if FIFO was empty (nothing real was read)
        if (prev_rd_en && prev_empty) begin
          $display("[MON] Skip - fifo was empty");

        // skip if data is not valid yet
        end else if (^vif.data_out === 1'bx) begin
          $display("[MON] Skip - data is X");

        // valid read - send to scoreboard
        end else begin
          txn          = new();
          txn.data_out = vif.data_out;
          txn.print("MON");
          mon2scb.put(txn);
        end
      end

      // save for next cycle
      prev_rptr  = vif.b_rptr_mon;
      prev_empty = vif.fifo_empty;
      prev_rd_en = vif.rd_en;
    end
  endtask

endclass
