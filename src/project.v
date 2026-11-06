/*
 * Copyright (c) 2026 Maohan Sun
 * SPDX-License-Identifier: Apache-2.0
 *
 * Ring-oscillator array for process variation and BTI aging on GF180MCU.
 *
 * 52 rings. Ring index i = 10*KIND + 2*COPY + MODE for i < 50
 *   KIND 0..4 = INV, NAND2-A1, NAND2-A2, NOR2-A1, NOR2-A2 (see ro_ring.v), 31 stages
 *   COPY 0..4 = five identical copies (local variation)
 *   MODE 0 = AC group (runs whenever stress_on = 1), MODE 1 = DC group (always parked)
 * Ring 50 = INV, 15 stages, AC group;  ring 51 = INV, 63 stages, DC group.
 *
 * Measurement: pulse ui_in[7] (start). The FSM stops every ring, clears the 24-bit ripple counter,
 * runs only the selected ring for 2^K clk cycles, stops it, waits, then raises done (uio_out[7]).
 * count = f_ring * 2^K / f_clk, read one byte at a time on uo_out.
 *
 * Pins
 *   ui_in[4:0], uio_in[3]: ring select bits 4..0 and bit 5
 *   ui_in[6:5] byte select (0 = LSB .. 2 = MSB, 3 = status {sel[5:0], done, busy})   ui_in[7] start
 *   uio_in[0]  stress_on       uio_in[2:1] window K: 0 -> 2^10, 1 -> 2^12, 2 -> 2^14, 3 -> 2^16
 *   uio_out[6] counter bit 7 (selected ring / 256, only while measuring)   uio_out[7] done
 */
`default_nettype none

module tt_um_maohansun_ro_aging (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  localparam integer NRO = 52;

  // ---------------- control (clk domain) ----------------
  reg [2:0] start_s;
  always @(posedge clk or negedge rst_n)
    if (!rst_n) start_s <= 3'b000;
    else        start_s <= {start_s[1:0], ui_in[7]};
  wire start_rise = start_s[1] & ~start_s[2];

  localparam [2:0] S_IDLE = 3'd0, S_CLR = 3'd1, S_RUN = 3'd2, S_SETTLE = 3'd3, S_DONE = 3'd4;
  reg  [2:0]  state;
  reg  [16:0] tmr;
  reg  [5:0]  sel_q;
  wire [16:0] win = (uio_in[2:1] == 2'd0) ? 17'd1024  :
                    (uio_in[2:1] == 2'd1) ? 17'd4096  :
                    (uio_in[2:1] == 2'd2) ? 17'd16384 : 17'd65536;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE; tmr <= 17'd0; sel_q <= 6'd0;
    end else begin
      case (state)
        S_IDLE:   if (start_rise) begin state <= S_CLR; tmr <= 17'd0; sel_q <= {uio_in[3], ui_in[4:0]}; end
        S_CLR:    if (tmr == 17'd3) begin state <= S_RUN; tmr <= 17'd0; end else tmr <= tmr + 17'd1;
        S_RUN:    if (tmr == win - 17'd1) begin state <= S_SETTLE; tmr <= 17'd0; end else tmr <= tmr + 17'd1;
        S_SETTLE: if (tmr == 17'd7) begin state <= S_DONE; tmr <= 17'd0; end else tmr <= tmr + 17'd1;
        S_DONE:   if (!start_s[1]) state <= S_IDLE;
        default:  state <= S_IDLE;
      endcase
    end
  end

  wire meas_run  = (state == S_RUN);
  wire cnt_clr   = (state == S_CLR) | ~rst_n;
  wire busy      = (state != S_IDLE);
  wire stress_on = uio_in[0];

  // ---------------- ring array ----------------
  wire [NRO-1:0] ro_out;
  reg  [NRO-1:0] ro_en;
  integer k;
  always @(*) begin
    for (k = 0; k < NRO; k = k + 1) begin
      // AC group: index < 50 with MODE (bit 0) = 0, plus ring 50
      ro_en[k] = (meas_run & (sel_q == k[5:0])) |
                 (~busy & stress_on & ((k < 50) ? (k[0] == 1'b0) : (k == 50)));
    end
  end

  genvar i;
  generate
    for (i = 0; i < 50; i = i + 1) begin : g_ro
      ro_ring #(.KIND(i / 10), .N(31)) ro (.en(ro_en[i]), .out(ro_out[i]));
    end
  endgenerate
  ro_ring #(.KIND(0), .N(15)) ro50 (.en(ro_en[50]), .out(ro_out[50]));
  ro_ring #(.KIND(0), .N(63)) ro51 (.en(ro_en[51]), .out(ro_out[51]));

  // ---------------- ripple counter on the selected ring ----------------
  wire ro_sel = ro_out[sel_q] & meas_run;
  wire [23:0] cnt;
  generate
    for (i = 0; i < 24; i = i + 1) begin : g_cnt
      wire tick = (i == 0) ? ro_sel : ~cnt[(i == 0) ? 0 : i - 1];   // bit i toggles on the fall of bit i-1
      reg  q;
      always @(posedge tick or posedge cnt_clr)
        if (cnt_clr) q <= 1'b0; else q <= ~q;
      assign cnt[i] = q;
    end
  endgenerate

  // ---------------- read-out ----------------
  wire [7:0] status = {sel_q, (state == S_DONE), busy};
  assign uo_out  = (ui_in[6:5] == 2'd0) ? cnt[7:0]   :
                   (ui_in[6:5] == 2'd1) ? cnt[15:8]  :
                   (ui_in[6:5] == 2'd2) ? cnt[23:16] : status;
  assign uio_out = {(state == S_DONE), cnt[7] & meas_run, 6'b0};
  assign uio_oe  = 8'b1100_0000;

  wire _unused = &{ena, uio_in[7:4], 1'b0};
endmodule
