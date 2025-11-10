# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

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

    # Simulate first button press for 16 debounce samples. It's a pain due to
    # needing to follow column scan (or multiple buttons appear to be pushed)
    for _ in range(16):
        dut.ui_in.value = 1
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0
        await ClockCycles(dut.clk, 2)

    # Since we know the LFSR seed and can count clock cycles
    # we can determine the starting LED state
    #   O 0 0
    #   O O O
    #   O 0 0
    led_pattern = 0x79

    # Check multiplexed LED behavior, it takes three clock cycles to run the multiplex
    for _ in range(3):
        if dut.uo_out.value[3]: # If COL0 active
            dut._log.info("Test COL0 - Initial")
            # Isolate the first columns LED's from the LED mask
            # Test as logical equality (not bitwise) to avoid needing to shift stuff
            # Rows are active low, so test for not-equal
            assert bool(dut.uo_out.value[0]) != bool(led_pattern & (1<<0)) # LED0: COL0, ROW0
            assert bool(dut.uo_out.value[1]) != bool(led_pattern & (1<<3)) # LED3: COL0, ROW1
            assert bool(dut.uo_out.value[2]) != bool(led_pattern & (1<<6)) # LED6: COL0, ROW2

        if dut.uo_out.value[4]: # If COL1 active
            dut._log.info("Test COL1 - Initial")
            assert bool(dut.uo_out.value[0]) != bool(led_pattern & (1<<1)) # LED1: COL1, ROW0
            assert bool(dut.uo_out.value[1]) != bool(led_pattern & (1<<4)) # LED4: COL1, ROW1
            assert bool(dut.uo_out.value[2]) != bool(led_pattern & (1<<7)) # LED7: COL1, ROW2

        if dut.uo_out.value[5]: # If COL2 active
            dut._log.info("Test COL2 - Initial")
            assert bool(dut.uo_out.value[0]) != bool(led_pattern & (1<<2)) # LED2: COL2, ROW0
            assert bool(dut.uo_out.value[1]) != bool(led_pattern & (1<<5)) # LED5: COL2, ROW1
            assert bool(dut.uo_out.value[2]) != bool(led_pattern & (1<<8)) # LED8: COL2, ROW2

        await ClockCycles(dut.clk, 1)

    # Now toggle the center button and make sure the LED's change correctly
    # Need an extra clock cycle to align with column scan
    await ClockCycles(dut.clk, 1)
    for _ in range(16):
        dut.ui_in.value = 2
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0
        await ClockCycles(dut.clk, 2)

    # Updated LED pattern
    #   O O 0
    #   0 0 0
    #   O O 0
    led_pattern = 0xC3

    # Check multiplexed LED behavior, it takes three clock cycles to run the multiplex
    for _ in range(3):
        if dut.uo_out.value[3]: # If COL0 active
            dut._log.info("Test COL0 - After Toggle")
            # Isolate the first columns LED's from the LED mask
            # Test as logical equality (not bitwise) to avoid needing to shift stuff
            # Rows are active low, so test for not-equal
            assert bool(dut.uo_out.value[0]) != bool(led_pattern & (1<<0)) # LED0: COL0, ROW0
            assert bool(dut.uo_out.value[1]) != bool(led_pattern & (1<<3)) # LED3: COL0, ROW1
            assert bool(dut.uo_out.value[2]) != bool(led_pattern & (1<<6)) # LED6: COL0, ROW2

        if dut.uo_out.value[4]: # If COL1 active
            dut._log.info("Test COL1 - After Toggle")
            assert bool(dut.uo_out.value[0]) != bool(led_pattern & (1<<1)) # LED1: COL1, ROW0
            assert bool(dut.uo_out.value[1]) != bool(led_pattern & (1<<4)) # LED4: COL1, ROW1
            assert bool(dut.uo_out.value[2]) != bool(led_pattern & (1<<7)) # LED7: COL1, ROW2

        if dut.uo_out.value[5]: # If COL2 active
            dut._log.info("Test COL2 - After Toggle")
            assert bool(dut.uo_out.value[0]) != bool(led_pattern & (1<<2)) # LED2: COL2, ROW0
            assert bool(dut.uo_out.value[1]) != bool(led_pattern & (1<<5)) # LED5: COL2, ROW1
            assert bool(dut.uo_out.value[2]) != bool(led_pattern & (1<<8)) # LED8: COL2, ROW2

        await ClockCycles(dut.clk, 1)
