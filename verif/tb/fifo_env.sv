class fifo_env;

  fifo_generator  gen;
  fifo_driver     drv;
  fifo_monitor    mon;
  fifo_scoreboard scb;

  mailbox #(fifo_transaction) gen2drv;
  mailbox #(fifo_transaction) mon2scb;
  mailbox #(logic [63:0])     drv2scb;

  virtual fifo_if vif;
  int total_txns = 0;

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

    while (gen2drv.num() > 0)
      @(posedge vif.wrclk);

    while ((scb.pass + scb.fail) < 24)  // wait until all 24 checked
  @(posedge vif.rdclk);             // check every clock edge 
    
    scb.report();

  endtask

endclass
