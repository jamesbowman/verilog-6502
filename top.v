`timescale 1ns/1ps
`default_nettype none


module rom(clk, en, a, d);
  parameter WIDTH = 8;
  parameter SIZE = 11;
  parameter INIT = "";
  input clk;
  input en;
  input [SIZE-1:0] a;
  output reg [WIDTH-1:0] d;

  reg [WIDTH-1:0] r[0:(1 << SIZE)-1];
  initial begin
    $readmemh({INIT}, r);
  end
  always @(posedge clk)
    if (en)
      d <= r[a];
endmodule

module bram_tdp #(
    parameter DATA = 8,
    parameter ADDR = 8
) (
    // Port A
    input    wire                a_clk,
    input    wire                a_wr,
    input    wire    [ADDR-1:0]  a_addr,
    input    wire    [DATA-1:0]  a_din,
    output   reg     [DATA-1:0]  a_dout,

    // Port B
    input    wire                b_clk,
    input    wire                b_wr,
    input    wire    [ADDR-1:0]  b_addr,
    input    wire    [DATA-1:0]  b_din,
    output   reg     [DATA-1:0]  b_dout
);
  reg [DATA-1:0] mem [(2**ADDR)-1:0];
  // Port A
  always @(posedge a_clk) begin
      a_dout      <= mem[a_addr];
      if(a_wr) begin
          a_dout      <= a_din;
          mem[a_addr] <= a_din;
      end
  end

  // Port B
  always @(posedge b_clk) begin
      b_dout      <= mem[b_addr];
      if(b_wr) begin
          b_dout      <= b_din;
          mem[b_addr] <= b_din;
      end
  end

endmodule

module top();

  integer t;
  integer i;
  reg clk, reset;

  cpu _cpu( clk, reset, AB, DI, DO, WE, IRQ, NMI, RDY );

  wire [15:0] AB;       // address bus
  reg [7:0] DI;         // data in, read bus
  wire [7:0] DO;        // data out, write bus
  wire WE;              // write enable
  reg IRQ;              // interrupt request
  reg NMI;              // non-maskable interrupt request
  reg RDY;              // Ready signal. Pauses CPU when RDY=0

  reg [15:0] AB_;
  always @(posedge clk)
    AB_ <= AB;

  wire [7:0] d00, d40, d50, d68, d70, d78;
  reg [7:0] d20;
  rom #(.INIT("035127.02.hex")) r50 (.clk(clk), .en(1'b1), .a(AB[10:0]), .d(d50));
  rom #(.INIT("035145.02.hex")) r68 (.clk(clk), .en(1'b1), .a(AB[10:0]), .d(d68));
  rom #(.INIT("035144.02.hex")) r70 (.clk(clk), .en(1'b1), .a(AB[10:0]), .d(d70));
  rom #(.INIT("035143.02.hex")) r78 (.clk(clk), .en(1'b1), .a(AB[10:0]), .d(d78));

  wire zram_we = (AB & 16'h7C00) == 16'h0000;
  reg RAMSEL = 0;

  wire reverse = AB[9] & RAMSEL;
  bram_tdp #(.DATA(8), .ADDR(10)) zram (
    .a_clk(clk),
    .a_wr(WE & zram_we),
    .a_addr({AB[9], AB[8] ^ reverse, AB[7:0]}),
    .a_din(DO),
    .a_dout(d00),

    .b_clk(clk),
    .b_wr(1'b0),
    .b_addr(10'd0),
    .b_din(8'd0),
    .b_dout()
    );

  always @(posedge clk)
    if (WE & (AB == 16'h3200))
      RAMSEL <= DO[2];

  wire sram_we = (AB & 16'h7800) == 16'h4000;

  bram_tdp #(.DATA(8), .ADDR(11)) sram (
    .a_clk(clk),
    .a_wr(WE & sram_we),
    .a_addr(AB[10:0]),
    .a_din(DO),
    .a_dout(d40),

    .b_clk(clk),
    .b_wr(1'b0),
    .b_addr(11'd0),
    .b_din(8'd0),
    .b_dout()
    );

  reg [8:0] divider = 0;
  always @(posedge clk)
    divider <= divider + 9'd1;

  always @(posedge clk)
    case (AB[15:0])
    15'h2001:  d20 <= {8{divider[8]}};
    15'h2007:  d20 <= 8'hff;             // SWTEST
    default:
      d20 <= 8'h00;
    endcase

  always @*
    case (AB_[15:0] & 16'h7800)
    16'h0000: DI = d00;
    16'h2000: DI = d20;
    16'h4000: DI = d40;
    16'h5000: DI = d50;
    16'h6800: DI = d68;
    16'h7000: DI = d70;
    16'h7800: DI = d78;
    endcase

  initial begin

    clk = 0;
    IRQ = 1;
    NMI = 1;
    RDY = 1;

    reset = 1; #20;
    reset = 0; #1;

    t = 0;

    while (t < 600000) begin
      if (t == -1) begin
        $dumpfile("dump.vcd"); $dumpvars(0);
      end
      #1;
    end


  end

  always #5 clk = ~clk;

  always @(negedge clk) begin
    if (t > 600000)
      $display("t=%d PC=%x A=%x X=%X Y=%x", t, _cpu.PC, _cpu.debug_A, _cpu.debug_X, _cpu.debug_Y);
    t += 1;
  end
  always @(posedge clk) begin
    if (WE & (AB == 16'h3000)) begin
      for (i = 0; i < 16; i++)
        $display("%x: %x", i, sram.mem[i]);
      $writememh("sram", sram.mem);
      $finish;
    end
  end

endmodule
