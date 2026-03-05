class fifo_scoreboard;

  mailbox #(fifo_transaction) mon2scb;  // reads  from monitor
  mailbox #(logic [63:0])     drv2scb; // writes from driver

  logic [63:0] wlist[$]; // list of written values (queue)
  int pass = 0;
  int fail = 0;

  function new(mailbox #(fifo_transaction) m,
               mailbox #(logic [63:0])     d);
    mon2scb = m;
    drv2scb = d;
  endfunction

  // collect writes from driver
  task collect_writes();
    logic [63:0] wdata;
    forever begin
      drv2scb.get(wdata);
      wlist.push_back(wdata);
      $display("[SCB] Write saved: %0h  list size=%0d", wdata, wlist.size());
    end
  endtask

  // check reads from monitor
  task check_reads();
    fifo_transaction txn;
    logic [63:0] expected;
    forever begin
      mon2scb.get(txn);
      expected = wlist.pop_front(); // oldest written value
      if (txn.data_out === expected) begin
        $display("[SCB] PASS: write=%0h  read=%0h", expected, txn.data_out);
        pass++;
      end else begin
        $display("[SCB] FAIL: write=%0h  read=%0h", expected, txn.data_out);
        fail++;
      end
    end
  endtask

  // run both at same time
  task run();
    fork
      collect_writes();
      check_reads();
    join
  endtask

  // print final result
  function void report();
    $display("\n======================");
    $display("  PASS : %0d", pass);
    $display("  FAIL : %0d", fail);
    if (fail == 0) $display("  *** TEST PASSED ***");
    else           $display("  *** TEST FAILED ***");
    $display("======================\n");
  endfunction

endclass
