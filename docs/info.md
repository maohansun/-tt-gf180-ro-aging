## How it works

The design contains 52 ring oscillators (ROs) built from hand-instantiated GF180MCU standard cells and one
24-bit ripple counter that measures the frequency of a selected ring.

| Ring index | Gate in every stage | Stages | Stress group |
|---|---|---|---|
| 0–9 | INV | 31 | even index AC, odd index DC |
| 10–19 | NAND2, signal on A1 (NMOS next to output) | 31 | even AC, odd DC |
| 20–29 | NAND2, signal on A2 (NMOS next to VSS) | 31 | even AC, odd DC |
| 30–39 | NOR2, signal on A1 (PMOS next to output) | 31 | even AC, odd DC |
| 40–49 | NOR2, signal on A2 (PMOS next to VDD) | 31 | even AC, odd DC |
| 50 | INV | 15 | AC |
| 51 | INV | 63 | DC |

Each gate type has five identical AC rings and five identical DC rings. When STRESS_ON is high and no
measurement is running, all AC rings oscillate (AC stress); DC rings stay parked in a fixed logic state (DC stress).

A measurement is started by a rising edge on START. The control logic stops every ring, clears the counter, runs only
the selected ring for 2^K clock cycles (K = 10, 12, 14 or 16, set by WIN1:WIN0), stops it again and raises DONE.
The ring frequency is

    f_ring = count * f_clk / 2^K

## How to test

1. Set the clock to 10 MHz, reset the design, keep STRESS_ON low.
2. Put the ring number (0–51) on SEL5 (uio[3]) and SEL4..SEL0, and the window on WIN1:WIN0.
3. Raise START and wait for DONE.
4. Read the count byte by byte with BYTE1:BYTE0 = 0 (LSB), 1, 2 (MSB). BYTE1:BYTE0 = 3 returns {SEL5..SEL0, DONE, BUSY}.
5. Release START before the next measurement.

For an aging experiment, record all 52 rings, then set STRESS_ON high (optionally at elevated temperature), and
repeat the read-out at increasing stress times. RO_DIV256 outputs the selected ring divided by 256 while a
measurement runs, as an independent check with an oscilloscope or the RP2040.

## External hardware

None. The RP2040 on the demo board drives the inputs and reads the outputs; an oscilloscope on RO_DIV256 is optional.
