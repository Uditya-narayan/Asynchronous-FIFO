// =============================================================================
// Single-file Asynchronous FIFO Testbench
// Combines all RTL and verification components in one file
// =============================================================================

// -----------------------------------------------------------------------------
// RTL: synchronizer.sv
// -----------------------------------------------------------------------------
module synchronizer #(parameter WIDTH=3) (input clk, rst_n, [WIDTH:0] d_in, output reg [WIDTH:0] d_out);
   reg [WIDTH:0] q1;
   always@(posedge clk) begin
     if(!rst_n) begin
       q1    <= 0;
       d_out <= 0;
     end
     else begin
       q1    <= d_in;
       d_out <= q1;
     end
    end
endmodule

// -----------------------------------------------------------------------------
// RTL: wrptr_handler.sv
// -----------------------------------------------------------------------------
module wptr_handler #(parameter PTR_WIDTH=3) (
   input wrclk, wrst_n, wr_en,
   input [PTR_WIDTH:0] g_rptr_sync,
   output reg [PTR_WIDTH:0] b_wptr, g_wptr,
   output reg fifo_full
   );

   reg [PTR_WIDTH:0] b_wptr_next;
   reg [PTR_WIDTH:0] g_wptr_next;

   reg wrap_around;
   wire wfull;

   assign b_wptr_next = b_wptr+(wr_en & !fifo_full);
   assign g_wptr_next = (b_wptr_next >>1)^b_wptr_next;

   always@(posedge wrclk or negedge wrst_n) begin
     if(!wrst_n) begin
       b_wptr <= 0;
       g_wptr <= 0;
     end
     else begin
       b_wptr <= b_wptr_next;
       g_wptr <= g_wptr_next;
     end
   end

   always@(posedge wrclk or negedge wrst_n) begin
     if(!wrst_n) fifo_full <= 0;
     else        fifo_full <= wfull;
   end

   assign wfull = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1], g_rptr_sync[PTR_WIDTH-2:0]});

endmodule

// -----------------------------------------------------------------------------
// RTL: rdptr_handler.sv
// -----------------------------------------------------------------------------
module rptr_handler #(parameter PTR_WIDTH=3) (
    input rdclk, rrst_n, rd_en,
    input [PTR_WIDTH:0] g_wptr_sync,
    output reg [PTR_WIDTH:0] b_rptr, g_rptr,
    output reg fifo_empty
    );

    reg [PTR_WIDTH:0] b_rptr_next;
    reg [PTR_WIDTH:0] g_rptr_next;
    wire rempty;

    assign b_rptr_next = b_rptr+(rd_en & !fifo_empty);
    assign g_rptr_next = (b_rptr_next >>1)^b_rptr_next;
    assign rempty = (g_wptr_sync == g_rptr_next);

    always@(posedge rdclk or negedge rrst_n) begin
     if(!rrst_n) begin
       b_rptr <= 0;
       g_rptr <= 0;
     end
     else begin
       b_rptr <= b_rptr_next;
       g_rptr <= g_rptr_next;
     end
    end

    always@(posedge rdclk or negedge rrst_n) begin
     if(!rrst_n) fifo_empty <= 1;
     else        fifo_empty <= rempty;
    end
endmodule

// -----------------------------------------------------------------------------
// RTL: fifo_memory.sv
// -----------------------------------------------------------------------------
module fifo_mem #(parameter FIFO_DEPTH=8, FIFO_WIDTH=16, PTR_WIDTH=3) (
   input wrclk, wr_en, rdclk, rd_en,
   input [PTR_WIDTH:0] b_wptr, b_rptr,
   input [FIFO_WIDTH-1:0] data_in,
   input fifo_full, fifo_empty,
   output reg [FIFO_WIDTH-1:0] data_out
   );
   reg [FIFO_WIDTH-1:0] fifo[0:FIFO_DEPTH-1];

   always@(posedge wrclk) begin
     if(wr_en & !fifo_full) begin
       fifo[b_wptr[PTR_WIDTH-1:0]] <= data_in;
     end
   end

   always@(posedge rdclk) begin
     if(rd_en & !fifo_empty) begin
       data_out <= fifo[b_rptr[PTR_WIDTH-1:0]];
     end
   end
endmodule

// -----------------------------------------------------------------------------
// RTL: fifo_top.sv
// -----------------------------------------------------------------------------
module asynchronous_fifo #(parameter FIFO_DEPTH=8, FIFO_WIDTH=64) (
  input wrclk, wrst_n,
  input rdclk, rrst_n,
  input wr_en, rd_en,
  input [FIFO_WIDTH-1:0] data_in,
  output reg [FIFO_WIDTH-1:0] data_out,
  output reg fifo_full, fifo_empty
  );

  parameter PTR_WIDTH = $clog2(FIFO_DEPTH);

  reg [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;
  reg [PTR_WIDTH:0] g_wptr, g_rptr;
  reg [PTR_WIDTH:0] b_wptr, b_rptr;

  wire [PTR_WIDTH-1:0] waddr, raddr;

  synchronizer #(PTR_WIDTH) sync_wptr (
    .clk    (rdclk),
    .rst_n  (rrst_n),
    .d_in   (g_wptr),
    .d_out  (g_wptr_sync)
  );

  synchronizer #(PTR_WIDTH) sync_rptr (
    .clk    (wrclk),
    .rst_n  (wrst_n),
    .d_in   (g_rptr),
    .d_out  (g_rptr_sync)
  );

  wptr_handler #(PTR_WIDTH) wrptr_h (
    .wrclk       (wrclk),
    .wrst_n      (wrst_n),
    .wr_en       (wr_en),
    .g_rptr_sync (g_rptr_sync),
    .b_wptr      (b_wptr),
    .g_wptr      (g_wptr),
    .fifo_full   (fifo_full)
  );

  rptr_handler #(PTR_WIDTH) rdptr_h (
    .rdclk       (rdclk),
    .rrst_n      (rrst_n),
    .rd_en       (rd_en),
    .g_wptr_sync (g_wptr_sync),
    .b_rptr      (b_rptr),
    .g_rptr      (g_rptr),
    .fifo_empty  (fifo_empty)
  );

  fifo_mem #(
    .FIFO_WIDTH (FIFO_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH),
    .PTR_WIDTH  (PTR_WIDTH)
  ) fifo (
    .wrclk      (wrclk),
    .wr_en      (wr_en),
    .rdclk      (rdclk),
    .rd_en      (rd_en),
    .b_wptr     (b_wptr),
    .b_rptr     (b_rptr),
    .data_in    (data_in),
    .fifo_full  (fifo_full),
    .fifo_empty (fifo_empty),
    .data_out   (data_out)
  );
endmodule

// -----------------------------------------------------------------------------
// Verification: fifo_if.sv  (interface)
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Verification: fifo_transaction.sv
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Verification: fifo_generator.sv
// -----------------------------------------------------------------------------
class fifo_generator;

  mailbox #(fifo_transaction) gen2drv;

  function new(mailbox #(fifo_transaction) mbx);
    gen2drv = mbx;
  endfunction

  task write_data(logic [63:0] data);
    fifo_transaction txn = new();
    txn.wr_en   = 1;
    txn.rd_en   = 0;
    txn.data_in = data;
    txn.print("GEN-WR");
    gen2drv.put(txn);
  endtask

  task read_data();
    fifo_transaction txn = new();
    txn.wr_en   = 0;
    txn.rd_en   = 1;
    txn.data_in = 0;
    txn.print("GEN-RD");
    gen2drv.put(txn);
  endtask

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

  task tc2_fill_fifo();
    $display("\n[GEN] == TC2: Fill FIFO Completely (8 values) ==");
    for (int i = 1; i <= 8; i++)
      write_data(64'hB000 + i);
    for (int i = 1; i <= 8; i++)
      read_data();
    $display("[GEN] TC2 Done\n");
  endtask

  task tc3_all_zeros();
    $display("\n[GEN] == TC3: Corner Case - All Zeros ==");
    write_data(64'h0000_0000_0000_0000);
    read_data();
    $display("[GEN] TC3 Done\n");
  endtask

  task tc4_all_ones();
    $display("\n[GEN] == TC4: Corner Case - All Ones ==");
    write_data(64'hFFFF_FFFF_FFFF_FFFF);
    read_data();
    $display("[GEN] TC4 Done\n");
  endtask

  task tc5_alternating_bits();
    $display("\n[GEN] == TC5: Alternating Bits ==");
    write_data(64'hAAAA_AAAA_AAAA_AAAA);
    write_data(64'h5555_5555_5555_5555);
    read_data();
    read_data();
    $display("[GEN] TC5 Done\n");
  endtask

  task tc6_write_read_together();
    $display("\n[GEN] == TC6: Write and Read Back to Back ==");
    for (int i = 1; i <= 8; i++) begin
      write_data(64'hC000 + i);
      read_data();
    end
    $display("[GEN] TC6 Done\n");
  endtask

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

// -----------------------------------------------------------------------------
// Verification: fifo_driver.sv
// -----------------------------------------------------------------------------
class fifo_driver;

  virtual fifo_if vif;
  mailbox #(fifo_transaction) gen2drv;
  mailbox #(logic [63:0])     drv2scb;

  function new(virtual fifo_if v,
               mailbox #(fifo_transaction) g,
               mailbox #(logic [63:0]) d);
    vif     = v;
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

  task run();
    fifo_transaction txn;
    forever begin
      gen2drv.get(txn);
      txn.print("DRV");

      @(posedge vif.wrclk);
      vif.wr_en   <= txn.wr_en;
      vif.data_in <= txn.data_in;

      @(posedge vif.wrclk);
      if (vif.wr_en && !vif.fifo_full)
        drv2scb.put(vif.data_in);
      vif.wr_en <= 0;

      @(posedge vif.rdclk);
      vif.rd_en <= txn.rd_en;
      vif.rd_en <= 0;
    end
  endtask

endclass

// -----------------------------------------------------------------------------
// Verification: fifo_monitor.sv
// -----------------------------------------------------------------------------
class fifo_monitor;

  virtual fifo_if vif;
  mailbox #(fifo_transaction) mon2scb;

  function new(virtual fifo_if v, mailbox #(fifo_transaction) m);
    vif     = v;
    mon2scb = m;
  endfunction

  task run();
    fifo_transaction txn;
    logic [3:0] prev_rptr  = 0;
    logic       prev_empty = 1;
    logic       prev_rd_en = 0;

    while (!vif.rrst_n) @(posedge vif.rdclk);
    repeat(2) @(posedge vif.rdclk); #2;
    $display("[MON] Started\n");

    forever begin
      @(posedge vif.rdclk); #2;

      if (vif.b_rptr_mon !== prev_rptr) begin
        if (prev_rd_en && prev_empty) begin
          $display("[MON] Skip - fifo was empty");
        end else if (^vif.data_out === 1'bx) begin
          $display("[MON] Skip - data is X");
        end else begin
          txn          = new();
          txn.data_out = vif.data_out;
          txn.print("MON");
          mon2scb.put(txn);
        end
      end

      prev_rptr  = vif.b_rptr_mon;
      prev_empty = vif.fifo_empty;
      prev_rd_en = vif.rd_en;
    end
  endtask

endclass

// -----------------------------------------------------------------------------
// Verification: fifo_scoreboard.sv
// -----------------------------------------------------------------------------
class fifo_scoreboard;

  mailbox #(fifo_transaction) mon2scb;
  mailbox #(logic [63:0])     drv2scb;

  logic [63:0] wlist[$];
  int pass = 0;
  int fail = 0;

  function new(mailbox #(fifo_transaction) m,
               mailbox #(logic [63:0])     d);
    mon2scb = m;
    drv2scb = d;
  endfunction

  task collect_writes();
    logic [63:0] wdata;
    forever begin
      drv2scb.get(wdata);
      wlist.push_back(wdata);
      $display("[SCB] Write saved: %0h  list size=%0d", wdata, wlist.size());
    end
  endtask

  task check_reads();
    fifo_transaction txn;
    logic [63:0] expected;
    forever begin
      mon2scb.get(txn);
      expected = wlist.pop_front();
      if (txn.data_out === expected) begin
        $display("[SCB] PASS: write=%0h  read=%0h", expected, txn.data_out);
        pass++;
      end else begin
        $display("[SCB] FAIL: write=%0h  read=%0h", expected, txn.data_out);
        fail++;
      end
    end
  endtask

  task run();
    fork
      collect_writes();
      check_reads();
    join
  endtask

  function void report();
    $display("\n======================");
    $display("  PASS : %0d", pass);
    $display("  FAIL : %0d", fail);
    if (fail == 0) $display("  *** TEST PASSED ***");
    else           $display("  *** TEST FAILED ***");
    $display("======================\n");
  endfunction

endclass

// -----------------------------------------------------------------------------
// Verification: fifo_env.sv
// -----------------------------------------------------------------------------
class fifo_env;

  fifo_generator  gen;
  fifo_driver     drv;
  fifo_monitor    mon;
  fifo_scoreboard scb;

  mailbox #(fifo_transaction) gen2drv;
  mailbox #(fifo_transaction) mon2scb;
  mailbox #(logic [63:0])     drv2scb;

  virtual fifo_if vif;

  int total_txns  = 0;
  int driven_txns = 0;

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

    repeat(20) @(posedge vif.wrclk);
    repeat(20) @(posedge vif.rdclk);

    scb.report();
  endtask

endclass

// -----------------------------------------------------------------------------
// Top-level testbench module: fifo_tb_top.sv
// -----------------------------------------------------------------------------
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

endmodule
