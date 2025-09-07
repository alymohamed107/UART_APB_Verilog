
vdel -all -lib work
vlib work
# Compile all source files
vlog baud.v
vlog UART_RX.v
vlog UART_TX.v
vlog APB.v
vlog APB_tb.v
vsim -gui work.APB_tb
add wave -r *
run -all
