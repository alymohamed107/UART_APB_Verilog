`timescale 1ns/1ps

module UART_tb;

    // Parameters
    parameter CLK_FREQ   = 100_000_000;   // 100 MHz
    parameter BAUD       = 9600;
    parameter DIV        = CLK_FREQ / BAUD;

    // DUT signals
    reg clk;
    reg arst_n;

    // TX
    reg        tx_en;
    reg [7:0]  tx_data;
    wire       tx;
    wire       tx_busy, tx_done;

    // RX
    reg        rx_en;
    wire [7:0] rx_data;
    wire       rx_busy, rx_error, rx_done;

   
    UART_TX #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) dut_tx (
        .clk(clk),
        .arst_n(arst_n),
        .tx_en(tx_en),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    UART_RX dut_rx (
        .clk(clk),
        .arst_n(arst_n),
        .rx_en(rx_en),
        .rx(tx),       // loopback TX -> RX
        .rx_busy(rx_busy),
        .rx_error(rx_error),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );


    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10 ns period
    end

 
    initial begin
       
        arst_n  = 0;
        tx_en   = 0;
        tx_data = 0;
        rx_en   = 0;
        #100;

      
        arst_n = 1;
        rx_en  = 1;
        #100;

        // Send byte 0xA5 = 10100101
        $display("Sending 0xA5...");
        tx_data = 8'hA5;
        tx_en   = 1;
        #10 tx_en = 0;  

        // Wait for TX done
        wait(tx_done);
        $display("TX finished at t=%0t", $time);

        // Wait for RX done
        wait(rx_done);
        $display("RX finished at t=%0t, data=%h", $time, rx_data);

    
        #1000 $stop;
    end

   
    initial begin
        $monitor("t=%0t ns : tx=%b, tx_busy=%b, rx_busy=%b, rx_data=%h, rx_done=%b, rx_error=%b",
                 $time, tx, tx_busy, rx_busy, rx_data, rx_done, rx_error);
    end

endmodule
