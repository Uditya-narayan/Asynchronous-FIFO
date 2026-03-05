module fifo_tb_top;

  logic wrclk, rdclk;

  initial wrclk = 0; always #25 wrclk = ~wrclk;
  initial rdclk = 0; always #10 rdclk = ~rdclk;

  // interface
  fifo_if dut_if (.wrclk(wrclk), .rdclk(rdclk));

  // DUT
  asynchronous_fifo #(.FIFO_DEPTH(8), .FIFO_WIDTH(64)) dut (
    .wrclk      (wrclk),
    .wrst_n     (dut_if.wrst_n),
    .rdclk      (rdclk),
    .rrst_n     (dut_if.rrst_n),
    .wr_en      (dut_if.wr_en),
    .rd_en      (dut_if.rd_en),
    .data_in    (dut_if.data_in),
    .data_out   (dut_if.data_out),
    .fifo_full  (dut_if.fifo_full),
    .fifo_empty (dut_if.fifo_empty)
  );

  // connect DUT internal read pointer to interface
  assign dut_if.b_rptr_mon = dut.rdptr_h.b_rptr;

  fifo_env env;
  initial begin
    $dumpfile("fifo_sim.vcd");
    $dumpvars(0, fifo_tb_top);
    $display("=== FIFO Test Start ===\n");
    env = new(dut_if);
    env.run();
    $display("=== FIFO Test End ===\n");
    $finish;
  end

  initial begin
    #20_000;
    $display("TIMEOUT");
    $finish;
  end

    initial begin
  `ifdef DUMP_ON
    `ifdef CADENCE
      $shm_open("./sig_cxl_amx_pm_top.shm");
      $shm_probe("ASM");
   `endif
 `endif
end
endmodule

