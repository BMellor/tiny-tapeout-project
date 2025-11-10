# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# Get the state of an LFSR given seed and clock cycles
def lfsr16(seed, clocks):
    lfsr = seed
    for _ in range(clocks):
        # Compute new bit: XOR taps at positions 15, 13, 12, 10 (0-indexed)
        new_bit = ((lfsr >> 15) ^ (lfsr >> 13) ^ (lfsr >> 12) ^ (lfsr >> 10)) & 1
        lfsr = ((lfsr << 1) & 0xFFFF) | new_bit
    return lfsr

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Push first button and test LED matrix startup state")

    dut.ui_in.value = 1 # push buttons
    # Pushes all buttons in the first row because it's a pain to simulate the real
    # behavior where you get pulsed input as the columns scan around the multiplex

    # Wait for 16 clock cycles for the button debouncers to fire
    await ClockCycles(dut.clk, 16)

    dut.ui_in.value = 0 # release buttons

    # Since we know the LFSR seed and can count clock cycles
    # we can determine the starting LED state
    led_pattern = lfsr16(0xBEEF, 16) & 0x1FF

    # Now the hard part of checking multiplexed LED behavior
    # after 16 clock cycles the 2nd column (COL1) should be active
    assert dut.uo_out.value == (led_pattern & 0x92)

    # Now check COL2 next clock cycle
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == (led_pattern & 0x124)

    # Now check COL0
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == (led_pattern & 0x49)

