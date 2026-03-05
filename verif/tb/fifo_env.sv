class fifo_env;

  fifo_generator  gen;
  fifo_driver     drv;
  fifo_monitor    mon;
  fifo_scoreboard scb;

  mailbox #(fifo_transaction) gen2drv;
  mailbox #(fifo_transaction) mon2scb;
  mailbox #(logic [63:0])     drv2scb;

  virtual fifo_if vif;

  // count transactions manually
  int total_txns  = 0;  // how many txns generator sent
  int driven_txns = 0;  // how many txns driver completed

  function new(virtual fifo_if v);
    vif     = v;
    gen2drv = new();
    mon2scb = new();
    drv2scb = new();
    gen = new(gen2drv);
    drv = new(vif, gen2drv, drv2scb);
    mon = new(vif, mon2scb);
    scb = new(mon2scb, drv2scb);
  endfunction

  task run();

    drv.reset();

    gen.run();
    total_txns = gen2drv.num();
    $display("[ENV] Total transactions to drive: %0d\n", total_txns);

    fork
      drv.run();
      mon.run();
      scb.run();
    join_none

    // check every wrclk until mailbox is empty
    while (gen2drv.num() > 0)
      @(posedge vif.wrclk);

    repeat(20) @(posedge vif.wrclk);
    repeat(20) @(posedge vif.rdclk);

    scb.report();

  endtask

endclass
