`timescale 1ns/1ps
`default_nettype none

module top();

  integer t;
  reg clk, reset;

  cpu _cpu( clk, reset, AB, DI, DO, WE, IRQ, NMI, RDY );

  wire [15:0] AB;       // address bus
  reg [7:0] DI;         // data in, read bus
  wire [7:0] DO;        // data out, write bus
  wire WE;              // write enable
  reg IRQ;              // interrupt request
  reg NMI;              // non-maskable interrupt request
  reg RDY;              // Ready signal. Pauses CPU when RDY=0 

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0);

    clk = 0;
    IRQ = 1;
    NMI = 1;
    RDY = 1;

    reset = 1; #20;
    reset = 0; #1;

    DI = 8'h4c;

    #100;
    $display("AB %x", AB);

    $finish;
  end
  
  always #5 clk = ~clk;

endmodule
