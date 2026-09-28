.PHONY: all clean sim elaborate compile help

# Simulator settings
SIMULATOR ?= xvlog
XVLOG_OPTS ?= -sv
XELAB_OPTS ?=
XSIM_OPTS ?= -gui

# Files
RTL_FILES = rtl/sync_fifo.sv
TB_FILES = tb/sync_fifo_tb.sv
TOP_MODULE = sync_fifo_tb

# Work directory
WORK_DIR = xwork

help:
	@echo "Synchronous FIFO Build System"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  make all       - Compile and elaborate (default)"
	@echo "  make compile   - Compile RTL and testbench"
	@echo "  make elaborate - Elaborate design"
	@echo "  make sim       - Run simulation (GUI mode)"
	@echo "  make sim_batch - Run simulation (batch mode)"
	@echo "  make clean     - Remove generated files"
	@echo "  make help      - Display this help message"
	@echo ""
	@echo "Variables:"
	@echo "  SIMULATOR  - Simulator tool (default: xvlog)"
	@echo "  XVLOG_OPTS - Compiler options"
	@echo ""

all: compile elaborate

compile:
	@echo "Compiling RTL and testbench..."
	xvlog $(XVLOG_OPTS) -work $(WORK_DIR) $(RTL_FILES) $(TB_FILES)
	@echo "Compilation complete"

elaborate: compile
	@echo "Elaborating design..."
	xelab $(XELAB_OPTS) -work $(WORK_DIR) $(TOP_MODULE)
	@echo "Elaboration complete"

sim: elaborate
	@echo "Starting simulation (GUI mode)..."
	xsim $(XSIM_OPTS) -work $(WORK_DIR) $(TOP_MODULE)

sim_batch: elaborate
	@echo "Running simulation (batch mode)..."
	xsim -work $(WORK_DIR) $(TOP_MODULE) -runall

# Alternative target using open-source tools (iverilog + vvp)
SIM_OPENIES = fifo_test

iverilog_sim:
	@echo "Compiling with Icarus Verilog..."
	iverilog -o $(SIM_OPENIES) $(RTL_FILES) $(TB_FILES)
	@echo "Running simulation..."
	vvp $(SIM_OPENIES)
	@echo "Simulation complete. Check sync_fifo.vcd for waveforms"

# Python-based simulator (works in environments without Verilog tools)
python_sim:
	@echo "Running Python FIFO simulator..."
	python3 sim_fifo.py
	@echo "Simulation complete. Check sync_fifo.vcd for waveforms"

gtkwave:
	@if [ -f sync_fifo.vcd ]; then \
		gtkwave sync_fifo.vcd &; \
	else \
		echo "Error: sync_fifo.vcd not found. Run 'make python_sim' or 'make iverilog_sim' first"; \
	fi

viewer:
	@echo "Opening waveform viewer in default browser..."
	@if [ -f wave_viewer.html ]; then \
		python3 -m webbrowser "file://$(PWD)/wave_viewer.html" 2>/dev/null || echo "Open wave_viewer.html manually in your browser"; \
	else \
		echo "Error: wave_viewer.html not found"; \
	fi

clean:
	@echo "Cleaning up..."
	rm -rf $(WORK_DIR)
	rm -f $(SIM_OPENIES)
	rm -f sync_fifo.vcd
	rm -rf .Xil
	rm -rf __pycache__
	@echo "Clean complete"

.SILENT: help
