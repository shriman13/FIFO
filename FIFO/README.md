# FIFO project for the ITR report

## What is included

- `fifo.v`: parameterised, single-clock FIFO. Defaults: 8 bits per word, 16 words.
- `fifo_test.v`: report configuration, 3 bits per word and 4 words, with debounced push-button requests. Use this as the synthesis top.
- `debounce.v`: two flip-flop button synchroniser and stable-level debounce logic; one tick per accepted press.
- `tb_fifo.v`: self-checking core testbench. Use this as the first simulation top.
- `tb_fifo_test.v`: self-checking testbench of the whole hierarchy. Uses a shorter debounce interval for simulation.
- `fifo_test.xdc`: 100 MHz clock constraint. It does not assign physical board pins or external I/O delays.
- `validation.txt`: actual local simulation results, clearly identified as Icarus Verilog results.

This is a fresh implementation based on the report's interfaces and configuration, not a transcription of complete original course source files. The read/write acceptance and debounce implementation have been made explicit.

## How this FIFO behaves

The memory holds four 3-bit values in the report configuration. The output continuously shows the oldest unread value, and is valid only when `empty` is low. On an accepted read, sample that value at the rising clock edge; the output then changes to the next head word. Output while empty is unspecified and may show old data or X. Reset invalidates all stored data without clearing the memory array.

Acceptance is determined from the full/empty status BEFORE the rising edge:

| Requests | Empty | Partly occupied | Full |
|---|---|---|---|
| Neither | No change | No change | No change |
| Write only | Write | Write | Block write |
| Read only | Block read | Read | Read |
| Write and read | Write only | Read old head and write new tail | Read only |

There is no empty-state bypass and no full-state replacement write. Pointers and occupancy update only for accepted transfers.

## 1. Create the Vivado project

1. Extract the ZIP to a short local path, for example `C:/FPGA/FIFO_Project`.
2. Create an RTL project called `FIFO_ITR`.
3. Add **Design Sources**: `fifo.v`, `debounce.v`, and `fifo_test.v`.
4. Add **Simulation Sources**: `tb_fifo.v` and `tb_fifo_test.v`.
5. Select the FPGA part used in your course or existing Vivado project. If you do not know it, send the part-selection screen before synthesis so we can choose and document a software target.
6. Add `fifo_test.xdc` as a constraint file.
7. In Design Sources, set `fifo_test` as top. In Simulation Sources, set `tb_fifo` as top. Do not add either testbench to Design Sources.

## 2. Run the core behavioural simulation

Select **Run Simulation > Run Behavioral Simulation**. Use **Run All**, or enter `run all` in the Tcl Console after simulation opens. The test finishes automatically. The simulation is about 11 microseconds; a default 1 microsecond run will not complete it.

Expected last console message for the normal 3-bit, 4-word test:

    ALL FIFO TESTS PASSED: 11 groups, 1057 checked cycles; width=3 depth=4

Add these signals to the waveform:

- `clk`, `reset`
- `write_to_fifo`, `read_from_fifo`
- `write_data_in`, `read_data_out`
- `fifo_count`, `fifo_full`, `fifo_empty`
- Optional: `dut/current_write_addr`, `dut/current_read_addr`

Set data radix to unsigned decimal for the initial demonstration. Zoom into the start of the simulation: the first fill writes 1, 3, 5, 7; the next two write attempts are rejected while full; then the queue is drained in that order. Inspect data just before each accepted read edge, not only after it. Zoom out separately to see wrap-around and simultaneous-request cases.

Capture (a) the fill/drain waveform, (b) an empty/full simultaneous-request interval, and (c) the final PASS console. Use the Vivado captures as the report evidence; the local validation log is a separate check.

## 3. Run the complete-hierarchy simulation

Close the first simulation, set `tb_fifo_test` as the simulation top, and launch behavioural simulation again. Run All.

Expected last message:

    ALL FIFO TOP TESTS PASSED: debounce, held buttons, full/empty blocking, and data order

The testbench overrides `DEBOUNCE_BITS` to 3, requiring 8 stable clocks. The normal synthesis configuration remains 22 bits: 2^22 / 100 MHz = 41.94304 ms, plus synchroniser latency. This test checks short bounce rejection, a single operation per press, long held presses, and ordered transfers through the full hierarchy. It is not an exhaustive physical-button validation.

## 4. Synthesis

1. Close simulation and confirm `fifo_test` is the design top.
2. Keep `DEBOUNCE_BITS=22` for the normal synthesis configuration.
3. Run Synthesis and open the Synthesized Design.
4. Open Report Utilization and the schematic. Capture the resource summary and hierarchy/schematic if needed.
5. Record the exact Vivado version and target part with the results.

The clock-only XDC supports clock definition; it does not provide complete board or I/O timing constraints. Synthesis resource estimates are not placed-and-routed timing closure. No LUT/FF usage or maximum frequency is claimed before your Vivado run.

## Report changes after the runs

Update Section 4.2 and Table 4.2 to match accepted read/write operations and the occupancy counter. Replace Section 4.6's unfixed-bug discussion with the correction and the test observations. Describe the synchroniser and stable-level debounce implementation in Section 4.4. Insert the Vivado screenshots and measured utilisation figures. We will revise these together after reviewing your outputs.

## Optional local command-line verification

With Icarus Verilog installed, run from this folder:

    iverilog -g2012 -Wall -s tb_fifo -o core_sim fifo.v tb_fifo.v
    vvp core_sim
    iverilog -g2012 -Wall -s tb_fifo_test -o top_sim fifo.v debounce.v fifo_test.v tb_fifo_test.v
    vvp top_sim

Append `+VCD` to the first `vvp` command to produce a VCD waveform file. This is optional; Vivado uses its own simulation waveform database.

## Official workflow references

AMD, Vivado Design Suite User Guide: Logic Simulation (UG900), Working with Simulation Sets:
https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Working-with-Simulation-Sets

AMD, Vivado Design Suite User Guide: Logic Simulation (UG900), Adding or Creating Simulation Source Files:
https://docs.amd.com/r/2024.1-English/ug900-vivado-logic-simulation/Adding-or-Creating-Simulation-Source-Files
