/*
 * Copyright (c) 2026 Maohan Sun
 * SPDX-License-Identifier: Apache-2.0
 *
 * Ring-oscillator primitive cells.
 * Synthesis / lint: hand-instantiated GF180MCU 7-track 5 V standard cells, so that every ring
 * stage is exactly the intended gate and the intended input pin.
 * RTL simulation (define RO_BEHAV): behavioural models with a 1 ns delay so the rings oscillate.
 *
 * Transistor stacking (gf180mcu_fd_sc_mcu7t5v0 CDL):
 *   nand2_1: NMOS series, A1 next to ZN, A2 next to VSS; PMOS parallel.
 *   nor2_1 : PMOS series, A1 next to ZN, A2 next to VDD; NMOS parallel.
 */
`default_nettype none

module ro_inv (input wire a, output wire y);
`ifdef RO_BEHAV
  assign #1 y = ~a;
`else
  gf180mcu_fd_sc_mcu7t5v0__inv_1 u_cell (.I(a), .ZN(y));
`endif
endmodule

module ro_nand2 (input wire a1, input wire a2, output wire y);
`ifdef RO_BEHAV
  assign #1 y = ~(a1 & a2);
`else
  gf180mcu_fd_sc_mcu7t5v0__nand2_1 u_cell (.A1(a1), .A2(a2), .ZN(y));
`endif
endmodule

module ro_nor2 (input wire a1, input wire a2, output wire y);
`ifdef RO_BEHAV
  assign #1 y = ~(a1 | a2);
`else
  gf180mcu_fd_sc_mcu7t5v0__nor2_1 u_cell (.A1(a1), .A2(a2), .ZN(y));
`endif
endmodule
