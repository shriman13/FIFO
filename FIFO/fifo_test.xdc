# Clock-only constraint for synthesis/timing analysis of fifo_test.
# Select the actual target part in Vivado. No board pin assignments are implied.
create_clock -name sys_clk -period 10.000 [get_ports clk_100MHz]
# External I/O delays and board constraints are intentionally not invented.
# Do not use this file as a complete board implementation constraint set.
