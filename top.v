`timescale 1ns/1ps
`default_nettype none

module top();
  integer t;
  integer i;
  integer frame = 0;
  reg clk, reset;
  wire GODVG;

  reg dvgclk = 0;
  reg [12:0] dvga;
  wire [7:0] dvgd;

  wire sw1start;

  asteroids _asteroids(
    .fastclk(clk),
    .reset(reset),
    .sw1start(sw1start),
    .GODVG(GODVG),
    .dvgclk(dvgclk),
    .dvga(dvga),
    .dvgd(dvgd));

  assign sw1start = (3 <= frame) & (frame < 5);

  initial begin

    // $dumpfile("dump.vcd"); $dumpvars(0);
    clk = 0;

    reset = 1; #100;
    reset = 0; #1;

    t = 0;
  end

  always #5 clk = ~clk;

  always @(negedge clk) begin
    if ((t % 16000) == 0) $display("t=%d", t / 16);
    // if ((t % 1000) == 0) $display("t=%d PC=%x A=%x X=%X Y=%x", t, _asteroids._cpu.PC, _asteroids._cpu.debug_A, _asteroids._cpu.debug_X, _asteroids._cpu.debug_Y);
    t += 1;
  end

  reg [7:0] snap [0:8191];

  task snapshot;
  begin
      for (i = 0; i < 8192; i++) begin
        dvga = i; #1;
        dvgclk = 1; #1; dvgclk = 0;
        snap[i] = dvgd;
      end
      $writememh({"snapshot"}, snap, 0, 8191);
  end
  endtask

  wire [7:0] dig1 = 8'h30 + ((frame / 100) % 10);
  wire [7:0] dig2 = 8'h30 + ((frame / 10) % 10);
  wire [7:0] dig3 = 8'h30 + (frame % 10);

  always @(posedge clk) begin
    if (GODVG) begin
      $display("FRAME", frame);
      $writememh({"sram", dig1, dig2, dig3}, _asteroids.sram.mem, 0, 2047);
      snapshot();
      if (frame == 0)
        $finish;
      frame = frame + 1;
    end
  end

endmodule
