class fifo_generator;

  mailbox #(fifo_transaction) gen2drv;

  function new(mailbox #(fifo_transaction) mbx);
    gen2drv = mbx;
  endfunction

  // ------------------------------------------------
  // HELPER: send one write transaction
  // ------------------------------------------------
  task write_data(logic [63:0] data);
    fifo_transaction txn = new();
    txn.wr_en   = 1;
    txn.rd_en   = 0;
    txn.data_in = data;
    txn.print("GEN-WR");
    gen2drv.put(txn);
  endtask

  // ------------------------------------------------
  // HELPER: send one read transaction
  // ------------------------------------------------
  task read_data();
    fifo_transaction txn = new();
    txn.wr_en   = 0;
    txn.rd_en   = 1;
    txn.data_in = 0;
    txn.print("GEN-RD");
    gen2drv.put(txn);
  endtask

  // ------------------------------------------------
  // TESTCASE 1: Normal write then read
  // Write 4 values one by one then read them back
  // ------------------------------------------------
  task tc1_normal_write_read();
    $display("\n[GEN] == TC1: Normal Write and Read ==");
    write_data(64'hA1);
    write_data(64'hA2);
    write_data(64'hA3);
    write_data(64'hA4);
    read_data();
    read_data();
    read_data();
    read_data();
    $display("[GEN] TC1 Done\n");
  endtask

  // ------------------------------------------------
  // TESTCASE 2: Fill FIFO completely
  // FIFO depth=32, write 32 values to fill it fully
  // then read all 32 back
  // ------------------------------------------------
  task tc2_fill_fifo();
    $display("\n[GEN] == TC2: Fill FIFO Completely (8 values) ==");
    // write 8 values - fills FIFO to max
    for (int i = 1; i <= 8; i++)
      write_data(64'hB000 + i);  // 0xB001, 0xB002 ... 0xB020
    // read all 8 back
    for (int i = 1; i <= 8; i++)
      read_data();
    $display("[GEN] TC2 Done\n");
  endtask

  // ------------------------------------------------
  // TESTCASE 3: Corner case - all zeros data
  // ------------------------------------------------
  task tc3_all_zeros();
    $display("\n[GEN] == TC3: Corner Case - All Zeros ==");
    write_data(64'h0000_0000_0000_0000);
    read_data();
    $display("[GEN] TC3 Done\n");
  endtask

  // ------------------------------------------------
  // TESTCASE 4: Corner case - all ones data
  // ------------------------------------------------
  task tc4_all_ones();
    $display("\n[GEN] == TC4: Corner Case - All Ones ==");
    write_data(64'hFFFF_FFFF_FFFF_FFFF);
    read_data();
    $display("[GEN] TC4 Done\n");
  endtask

  // ------------------------------------------------
  // TESTCASE 5: Alternating bits
  // ------------------------------------------------
  task tc5_alternating_bits();
    $display("\n[GEN] == TC5: Alternating Bits ==");
    write_data(64'hAAAA_AAAA_AAAA_AAAA); // 1010 1010 pattern
    write_data(64'h5555_5555_5555_5555); // 0101 0101 pattern
    read_data();
    read_data();
    $display("[GEN] TC5 Done\n");
  endtask

  // ------------------------------------------------
  // TESTCASE 6: Write and read simultaneously
  // write one then immediately read one (back to back)
  // ------------------------------------------------
  task tc6_write_read_together();
    $display("\n[GEN] == TC6: Write and Read Back to Back ==");
    for (int i = 1; i <= 8; i++) begin
      write_data(64'hC000 + i);  // write one
      read_data();               // read one right after
    end
    $display("[GEN] TC6 Done\n");
  endtask

  // ------------------------------------------------
  // RUN ALL TESTCASES
  // ------------------------------------------------
  task run();
    tc1_normal_write_read();
    tc2_fill_fifo();
    tc3_all_zeros();
    tc4_all_ones();
    tc5_alternating_bits();
    tc6_write_read_together();
    $display("[GEN] All testcases done.");
  endtask

endclass
