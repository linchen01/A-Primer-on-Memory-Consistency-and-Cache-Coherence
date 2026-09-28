#!/usr/bin/env python3
"""
Synchronous FIFO Simulator
Generates VCD waveform file for GTKwave visualization
"""

import sys
from datetime import datetime

class SyncFIFO:
    def __init__(self, width=8, depth=8):
        self.width = width
        self.depth = depth
        self.addr_width = (depth - 1).bit_length()

        self.memory = [0] * depth
        self.wr_ptr = 0
        self.rd_ptr = 0
        self.wr_ptr_next = 0
        self.rd_ptr_next = 0

    def is_empty(self):
        return self.wr_ptr == self.rd_ptr

    def is_full(self):
        wr_ptr_next = (self.wr_ptr + 1) % (1 << (self.addr_width + 1))
        msb_match = (wr_ptr_next >> self.addr_width) != (self.rd_ptr >> self.addr_width)
        addr_match = (wr_ptr_next & ((1 << self.addr_width) - 1)) == (self.rd_ptr & ((1 << self.addr_width) - 1))
        return msb_match and addr_match

    def get_count(self):
        if self.wr_ptr >= self.rd_ptr:
            return self.wr_ptr - self.rd_ptr
        else:
            return (self.depth - self.rd_ptr) + self.wr_ptr

    def write(self, data):
        if not self.is_full():
            addr = self.wr_ptr & ((1 << self.addr_width) - 1)
            self.memory[addr] = data
            self.wr_ptr = (self.wr_ptr + 1) % (1 << (self.addr_width + 1))
            return True
        return False

    def read(self):
        if not self.is_empty():
            addr = self.rd_ptr & ((1 << self.addr_width) - 1)
            data = self.memory[addr]
            self.rd_ptr = (self.rd_ptr + 1) % (1 << (self.addr_width + 1))
            return data
        return 0

    def peek(self):
        if not self.is_empty():
            addr = self.rd_ptr & ((1 << self.addr_width) - 1)
            return self.memory[addr]
        return 0


class VCDWriter:
    def __init__(self, filename):
        self.filename = filename
        self.file = open(filename, 'w')
        self.timestamp = 0
        self.var_map = {}
        self.var_counter = 0

    def write_header(self):
        self.file.write("$date\n")
        self.file.write(f"  {datetime.now().strftime('%a %b %d %H:%M:%S %Y')}\n")
        self.file.write("$end\n")
        self.file.write("$version\n")
        self.file.write("  FIFO Simulator v1.0\n")
        self.file.write("$end\n")
        self.file.write("$timescale 1ns $end\n")
        self.file.write("$scope module sync_fifo_tb $end\n")

    def declare_var(self, var_type, width, name):
        char = chr(33 + self.var_counter)
        self.var_counter += 1
        if var_type == 'wire':
            self.file.write(f"$var wire {width} {char} {name} $end\n")
        else:
            self.file.write(f"$var reg {width} {char} {name} $end\n")
        self.var_map[name] = (char, width)
        return char

    def close_header(self):
        self.file.write("$upscope $end\n")
        self.file.write("$enddefinitions $end\n")

    def write_timestamp(self, ts):
        self.file.write(f"#{ts}\n")
        self.timestamp = ts

    def write_value(self, var_name, value):
        char, width = self.var_map[var_name]
        if width == 1:
            self.file.write(f"{value & 1}{char}\n")
        else:
            hex_val = hex(value)[2:].upper().zfill((width + 3) // 4)
            self.file.write(f"b{bin(value)[2:].zfill(width)} {char}\n")

    def close(self):
        self.file.close()


def simulate():
    fifo = SyncFIFO(width=8, depth=8)
    vcd = VCDWriter("sync_fifo.vcd")

    vcd.write_header()

    # Declare variables
    clk = vcd.declare_var('reg', 1, 'clk')
    rst_n = vcd.declare_var('reg', 1, 'rst_n')
    wr_en = vcd.declare_var('reg', 1, 'wr_en')
    wr_data = vcd.declare_var('reg', 8, 'wr_data')
    full = vcd.declare_var('wire', 1, 'full')
    rd_en = vcd.declare_var('reg', 1, 'rd_en')
    rd_data = vcd.declare_var('wire', 8, 'rd_data')
    empty = vcd.declare_var('wire', 1, 'empty')
    count = vcd.declare_var('wire', 4, 'count')

    vcd.close_header()

    # Simulation sequence
    ts = 0

    # Reset phase
    vcd.write_timestamp(ts)
    vcd.write_value('clk', 0)
    vcd.write_value('rst_n', 0)
    vcd.write_value('wr_en', 0)
    vcd.write_value('rd_en', 0)
    vcd.write_value('wr_data', 0)
    vcd.write_value('full', 0)
    vcd.write_value('empty', 1)
    vcd.write_value('rd_data', 0)
    vcd.write_value('count', 0)

    ts += 5
    vcd.write_timestamp(ts)
    vcd.write_value('clk', 1)

    ts += 5
    vcd.write_timestamp(ts)
    vcd.write_value('clk', 0)
    vcd.write_value('rst_n', 1)

    # Test 1: Write 8 items
    print("Test 1: Writing 8 items...")
    for i in range(8):
        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 1)
        vcd.write_value('wr_en', 1)
        vcd.write_value('wr_data', i)
        vcd.write_value('full', 1 if fifo.is_full() else 0)
        vcd.write_value('empty', 1 if fifo.is_empty() else 0)
        vcd.write_value('count', fifo.get_count())

        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 0)
        fifo.write(i)
        vcd.write_value('full', 1 if fifo.is_full() else 0)
        vcd.write_value('count', fifo.get_count())

    vcd.write_value('wr_en', 0)

    # Test 2: Read 8 items
    print("Test 2: Reading 8 items...")
    for i in range(8):
        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 1)
        vcd.write_value('rd_en', 1)
        vcd.write_value('rd_data', fifo.peek())
        vcd.write_value('empty', 1 if fifo.is_empty() else 0)
        vcd.write_value('count', fifo.get_count())

        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 0)
        data = fifo.read()
        vcd.write_value('empty', 1 if fifo.is_empty() else 0)
        vcd.write_value('count', fifo.get_count())
        print(f"  Read: 0x{data:02x}")

    vcd.write_value('rd_en', 0)

    # Test 3: Simultaneous read/write
    print("Test 3: Simultaneous read/write...")

    # Fill halfway
    for i in range(4):
        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 1)
        vcd.write_value('wr_en', 1)
        vcd.write_value('wr_data', 0xA0 + i)
        vcd.write_value('count', fifo.get_count())

        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 0)
        fifo.write(0xA0 + i)
        vcd.write_value('count', fifo.get_count())

    vcd.write_value('wr_en', 0)

    # Simultaneous R/W
    for i in range(8):
        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 1)
        vcd.write_value('wr_en', 1)
        vcd.write_value('rd_en', 1)
        vcd.write_value('wr_data', 0xB0 + i)
        vcd.write_value('rd_data', fifo.peek())
        vcd.write_value('count', fifo.get_count())

        ts += 5
        vcd.write_timestamp(ts)
        vcd.write_value('clk', 0)
        fifo.read()
        fifo.write(0xB0 + i)
        vcd.write_value('count', fifo.get_count())

    vcd.write_value('wr_en', 0)
    vcd.write_value('rd_en', 0)

    # Final timestamp
    ts += 10
    vcd.write_timestamp(ts)
    vcd.write_value('clk', 1)

    ts += 10
    vcd.write_timestamp(ts)
    vcd.write_value('clk', 0)

    vcd.close()
    print("\nSimulation complete!")
    print(f"VCD file generated: sync_fifo.vcd")


if __name__ == '__main__':
    simulate()
