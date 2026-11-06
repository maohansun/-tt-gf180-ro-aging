/*
 * Copyright (c) 2026 Maohan Sun
 * SPDX-License-Identifier: Apache-2.0
 *
 * One ring oscillator of N (odd) stages, all of the same gate type and the same input pin.
 *   KIND 0: INV           stage 0 = NAND2(A1 = loop, A2 = en)
 *   KIND 1: NAND2, pin A1 every stage: NAND2(A1 = loop, A2 = 1); stage 0 A2 = en
 *   KIND 2: NAND2, pin A2 every stage: NAND2(A1 = 1, A2 = loop); stage 0 A1 = en
 *   KIND 3: NOR2,  pin A1 every stage: NOR2(A1 = loop, A2 = 0);  stage 0 A2 = ~en
 *   KIND 4: NOR2,  pin A2 every stage: NOR2(A1 = 0, A2 = loop);  stage 0 A1 = ~en
 * en = 0 stops the ring in a fixed (parked) logic state: every node is static, i.e. DC stress.
 */
`default_nettype none

module ro_ring #(parameter integer KIND = 0, parameter integer N = 31) (
    input  wire en,
    output wire out
);
  /* verilator lint_off UNOPTFLAT */
  wire [N-1:0] s;
  /* verilator lint_on UNOPTFLAT */
  wire en_n;
  assign out = s[N-1];

  generate
    if (KIND == 0 || KIND == 1) begin : g_s0_nand_a1
      ro_nand2 st0 (.a1(s[N-1]), .a2(en), .y(s[0]));
    end else if (KIND == 2) begin : g_s0_nand_a2
      ro_nand2 st0 (.a1(en), .a2(s[N-1]), .y(s[0]));
    end else if (KIND == 3) begin : g_s0_nor_a1
      ro_inv ien (.a(en), .y(en_n));
      ro_nor2 st0 (.a1(s[N-1]), .a2(en_n), .y(s[0]));
    end else begin : g_s0_nor_a2
      ro_inv ien (.a(en), .y(en_n));
      ro_nor2 st0 (.a1(en_n), .a2(s[N-1]), .y(s[0]));
    end
    if (KIND < 3) begin : g_no_en_n
      assign en_n = 1'b0;
    end

    genvar i;
    for (i = 1; i < N; i = i + 1) begin : g_st
      if (KIND == 0) begin : g_inv
        ro_inv st (.a(s[i-1]), .y(s[i]));
      end else if (KIND == 1) begin : g_nand_a1
        ro_nand2 st (.a1(s[i-1]), .a2(1'b1), .y(s[i]));
      end else if (KIND == 2) begin : g_nand_a2
        ro_nand2 st (.a1(1'b1), .a2(s[i-1]), .y(s[i]));
      end else if (KIND == 3) begin : g_nor_a1
        ro_nor2 st (.a1(s[i-1]), .a2(1'b0), .y(s[i]));
      end else begin : g_nor_a2
        ro_nor2 st (.a1(1'b0), .a2(s[i-1]), .y(s[i]));
      end
    end
  endgenerate

  wire _unused = &{en_n, 1'b0};
endmodule
