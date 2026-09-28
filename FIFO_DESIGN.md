# Synchronous FIFO Design Documentation

## Overview
This document describes a synchronous FIFO (First-In-First-Out) implementation with a fixed depth of 8 entries and configurable data width.

## Design Parameters

- **Depth**: 8 entries (fixed)
- **Data Width**: 32 bits (default, configurable via parameter)
- **Type**: Synchronous (single clock domain)
- **Pointer Width**: 4 bits (3 bits for address + 1 bit for wrap detection)

## Architecture

### Block Diagram
```
┌─────────────────────────────────────────┐
│         Synchronous FIFO (Depth=8)      │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Memory Array [8][WIDTH-1:0]     │  │
│  └──────────────────────────────────┘  │
│           ▲                    ▲        │
│           │ wr_ptr             │ rd_ptr │
│           │                    │        │
│  ┌────────┴──────┐      ┌──────┴──────┐ │
│  │ Write Logic   │      │ Read Logic   │ │
│  └───────────────┘      └──────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### Key Components

1. **FIFO Memory**: 8-entry register array, indexed by write/read pointers
2. **Write Pointer (wr_ptr)**: 3-bit address + 1-bit wrap flag
3. **Read Pointer (rd_ptr)**: 3-bit address + 1-bit wrap flag
4. **Control Logic**: Generates empty, full, and count signals

### Control Signals

#### Empty Detection
- FIFO is empty when `wr_ptr == rd_ptr`
- Reading from an empty FIFO returns undefined data (no error signal)

#### Full Detection
- FIFO is full when the next write position equals the read pointer
- Write pointer wraps at address 8 (MSB of pointer differs from address match)
- Condition: `(wr_ptr_next[2:0] == rd_ptr[2:0]) && (wr_ptr_next[3] != rd_ptr[3])`

#### Count Calculation
- Number of valid entries in FIFO
- Calculated as the difference between write and read pointers
- Handles wrap-around correctly using extended pointer width

## Port Description

### Clock and Reset
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `clk` | 1 | Input | Synchronous clock |
| `rst_n` | 1 | Input | Active-low asynchronous reset |

### Write Port
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `wr_en` | 1 | Input | Write enable (ignored when FIFO is full) |
| `wr_data` | WIDTH | Input | Data to write |
| `full` | 1 | Output | FIFO is full (ready to be written after this cycle) |

### Read Port
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `rd_en` | 1 | Input | Read enable (ignored when FIFO is empty) |
| `rd_data` | WIDTH | Output | Data read from FIFO (combinatorial) |
| `empty` | 1 | Output | FIFO is empty |

### Status Signals
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `count` | 4 | Output | Number of valid entries (0-8) |

## Behavior Details

### Write Operation
- When `wr_en = 1` and `full = 0`, data is written to FIFO memory at position `wr_ptr`
- Write pointer increments on the next clock edge
- When `full = 1`, write is ignored

### Read Operation
- Read data is combinatorial based on current `rd_ptr`
- When `rd_en = 1` and `empty = 0`, read pointer increments on the next clock edge
- When `empty = 1`, read pointer doesn't change and `rd_data` is undefined

### Simultaneous Read/Write
- Both read and write can occur in the same cycle
- FIFO count remains unchanged if both enabled simultaneously
- No priority - both operations complete in parallel

## Timing

### Clock-to-Q Delay
- Read data: Combinatorial (memory read)
- Write pointer: Sequential (FF output)
- Read pointer: Sequential (FF output)
- Empty/Full flags: Combinatorial

### Setup/Hold
- Standard flip-flop timing for write/read enables
- No critical path concerns for depth of 8

## Reset Behavior

When `rst_n` is asserted (active-low):
1. Write pointer resets to 0
2. Read pointer resets to 0
3. FIFO memory is cleared to 0 (optional, depends on implementation)
4. FIFO is empty: `empty = 1`, `full = 0`, `count = 0`

## Testing

### Test Coverage
The testbench (`sync_fifo_tb.sv`) includes:
1. **Reset Test**: Verifies initial state
2. **Write Full Test**: Fills FIFO and checks full flag
3. **Read Empty Test**: Empties FIFO and checks empty flag
4. **Simultaneous R/W Test**: Verifies parallel operations
5. **Write When Full Test**: Verifies writes are ignored when full
6. **Read When Empty Test**: Verifies reads don't affect empty FIFO

### Running Tests
```bash
# Using Vivado/ModelSim
vlog rtl/sync_fifo.sv tb/sync_fifo_tb.sv
vsim sync_fifo_tb

# Using open-source tools (Icarus Verilog)
iverilog -o fifo_test rtl/sync_fifo.sv tb/sync_fifo_tb.sv
vvp fifo_test
```

## Synthesis Notes

- No asynchronous clear in memory (relies on reset)
- All logic is synchronous except read data (combinatorial read)
- Memory can be inferred as distributed RAM or block RAM depending on target
- No clock gating or power management features

## Limitations and Future Enhancements

1. **No programmable almost-full/almost-empty**: Could be added if needed
2. **No error flags**: Overflow/underflow detection could be added
3. **Single clock domain only**: Multi-clock domain FIFO would require CDC
4. **No data valid signal for read**: Read data is always present
5. **Fixed depth of 8**: Could be parameterized in future versions

## File Structure

```
├── rtl/
│   └── sync_fifo.sv          # RTL implementation
├── tb/
│   └── sync_fifo_tb.sv       # SystemVerilog testbench
└── FIFO_DESIGN.md            # This documentation
```

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-09-28 | Initial design with depth=8 |

