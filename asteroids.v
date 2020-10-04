module rom(clka, ena, aa, da,   clkb, enb, ab, db);
  parameter WIDTH = 8;
  parameter SIZE = 11;
  parameter INIT = "";

  input wire clka;
  input wire ena;
  input wire [SIZE-1:0] aa;
  output reg [WIDTH-1:0] da;

  input wire clkb;
  input wire enb;
  input wire [SIZE-1:0] ab;
  output reg [WIDTH-1:0] db;

  reg [WIDTH-1:0] r[0:(1 << SIZE)-1];
  initial begin
    $readmemh({INIT}, r);
  end
  always @(posedge clka)
    if (ena)
      da <= r[aa];
  always @(posedge clkb)
    if (enb)
      db <= r[ab];
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
    integer i;
  reg [DATA-1:0] mem [(2**ADDR)-1:0];
  initial begin
    for (i = 0; i < (2**ADDR); i++)
      mem[i] <= 8'he9;
  end
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

module asteroids(
  input wire clk,
  input wire reset,
  input wire sw1start,
  output wire GODVG,
  input wire dvgclk,
  input wire [12:0] dvga,
  output wire [7:0] dvgd
  );

  wire [15:0] AB;       // address bus
  reg [7:0] DI;         // data in, read bus
  wire [7:0] DO;        // data out, write bus
  wire WE;              // write enable
  wire IRQ;             // interrupt request
  wire NMI;             // non-maskable interrupt request
  wire RDY;             // Ready signal. Pauses CPU when RDY=0
  cpu _cpu( clk, reset, AB, DI, DO, WE, IRQ, NMI, RDY );

  assign IRQ = 1;
  assign RDY = 1;

  reg dvgs;
  always @(posedge dvgclk)
    dvgs <= dvga[12];
  wire [7:0] dvgad0, dvgad1;
  assign dvgd = dvgs ? dvgad1 : dvgad0;

  reg [15:0] AB_;
  always @(posedge clk)
    AB_ <= AB;

  wire [7:0] d00, d40, d50, d68, d70, d78;
  reg [7:0] d20;
  rom #(.INIT("035127.02.hex")) r50 (
    .clka(clk), .ena(1'b1), .aa(AB[10:0]), .da(d50),
    .clkb(dvgclk), .enb(1'b1), .ab(dvga[10:0]), .db(dvgad1));
  rom #(.INIT("035145.02.hex")) r68 (.clka(clk), .ena(1'b1), .aa(AB[10:0]), .da(d68));
  rom #(.INIT("035144.02.hex")) r70 (.clka(clk), .ena(1'b1), .aa(AB[10:0]), .da(d70));
  rom #(.INIT("035143.02.hex")) r78 (.clka(clk), .ena(1'b1), .aa(AB[10:0]), .da(d78));

  wire zram_we = (AB & 16'h7C00) == 16'h0000;
  reg RAMSEL = 0;

  wire reverse = AB[9] & RAMSEL;
  bram_tdp #(.DATA(8), .ADDR(10)) zram (
    .a_clk(clk),
    .a_wr(WE & zram_we),
    .a_addr({AB[9], AB[8] ^ reverse, AB[7:0]}),
    .a_din(DO),
    .a_dout(d00),

    .b_clk(dvgclk),
    .b_wr(1'b0),
    .b_addr(10'd0),
    .b_din(8'd0),
    .b_dout()
    );

  always @(posedge dvgclk)
    if (WE & (AB == 16'h3200))
      RAMSEL <= DO[2];

  wire sram_we = (AB & 16'h7800) == 16'h4000;

  bram_tdp #(.DATA(8), .ADDR(11)) sram (
    .a_clk(clk),
    .a_wr(WE & sram_we),
    .a_addr(AB[10:0]),
    .a_din(DO),
    .a_dout(d40),

    .b_clk(dvgclk),
    .b_addr(dvga[10:0]),
    .b_dout(dvgad0)
    );

  reg [12:0] div250 = 0;
  wire div250w = (div250 == 13'd5999);
  always @(posedge clk)
    div250 <= div250w ? 13'd0 : (div250 + 13'd1);
  assign NMI = ~div250w;

  reg [8:0] divider = 0;
  always @(posedge clk)
    divider <= divider + 9'd1;

  always @(posedge clk)
    case (AB[15:0])
    15'h2001:  d20 <= {8{divider[8]}};
    15'h2007:  d20 <= 8'h00;             // SWTEST
    15'h2403:  d20 <= {8{sw1start}};     // SW1START
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

  assign GODVG = WE & (AB == 16'h3000);

endmodule

