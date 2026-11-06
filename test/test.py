# SPDX-FileCopyrightText: © 2026 Maohan Sun
# SPDX-License-Identifier: Apache-2.0
#
# RTL test (behavioural ring cells, 1 ns per stage): every ring must give
#   count = window * T_clk / (2 * N * 1 ns)  within a few counts.
# Gate-level test: the functional cell models have zero delay, so a running ring cannot be
# simulated; only the control path (reset, status byte, idle outputs) is checked there.
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

GL = os.environ.get("GATES") == "yes"
T_CLK_NS = 100            # 10 MHz
WINDOW = {0: 1024, 1: 4096, 2: 16384, 3: 65536}


def ring_stages(idx):
    return 15 if idx == 50 else 63 if idx == 51 else 31


async def reset(dut):
    clock = Clock(dut.clk, T_CLK_NS, unit="ns")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


def set_sel(dut, ui_extra, sel, k=0):
    dut.ui_in.value = ui_extra | (sel & 0x1F)
    dut.uio_in.value = (k << 1) | (((sel >> 5) & 1) << 3)


async def read_byte(dut, b, sel, k=0):
    set_sel(dut, b << 5, sel, k)
    await ClockCycles(dut.clk, 2)
    return int(dut.uo_out.value)


async def measure(dut, sel, k=0):
    set_sel(dut, 0, sel, k)
    await ClockCycles(dut.clk, 2)
    set_sel(dut, 0x80, sel, k)                         # start
    for _ in range(WINDOW[k] + 200):
        await ClockCycles(dut.clk, 1)
        if (int(dut.uio_out.value) >> 7) & 1:
            break
    else:
        raise AssertionError("done never asserted")
    c = 0
    for b in range(3):
        c |= (await read_byte(dut, b, sel, k)) << (8 * b)
    set_sel(dut, 0, sel, k)                               # release start -> idle
    await ClockCycles(dut.clk, 4)
    return c


@cocotb.test()
async def test_control(dut):
    await reset(dut)
    st = await read_byte(dut, 3, 0)
    assert st & 0x3 == 0, f"done/busy after reset {st & 3}"
    assert (int(dut.uio_out.value) >> 6) == 0, "done / div output must be low when idle"
    assert int(dut.uio_oe.value) == 0xC0


@cocotb.test(skip=GL)
async def test_rings(dut):
    await reset(dut)
    for sel in [0, 1, 9, 10, 19, 20, 29, 30, 39, 40, 49, 50, 51]:
        c = await measure(dut, sel, k=0)
        exp = WINDOW[0] * T_CLK_NS / (2 * ring_stages(sel))
        dut._log.info(f"ring {sel:2d}: count {c}, expected {exp:.1f}")
        assert abs(c - exp) <= 3, f"ring {sel}: {c} vs {exp:.1f}"
        st = await read_byte(dut, 3, sel)
        assert (st >> 2) == sel, "status must report the measured ring"
