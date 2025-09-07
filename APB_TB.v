`timescale 1ns/1ps

module APB_tb;

    // Clock & reset
    reg PCLK;
    reg PRESETn;

    // APB interface
    reg        PSEL;
    reg        PENABLE;
    reg        PWRITE;
    reg [31:0] PADDR;
    reg [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire       PREADY;

    // UART control/status/data wires
    wire [3:0] ctrl_reg;
    wire       rx_done;
    wire       tx_done;
    wire       tx_busy;
    wire       rx_error;
    wire       rx_busy;
    wire [7:0] rx_data;
    wire [7:0] tx_data;

    wire       tx_serial; 
   

    APB dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),

        .ctrl_reg(ctrl_reg),
        .rx_done(rx_done),
        .tx_done(tx_done),
        .tx_busy(tx_busy),
        .rx_error(rx_error),
        .rx_busy(rx_busy),
        .rx_data(rx_data),
        .tx_data(tx_data)
    );

 
    UART_TX #(
        .CLK_FREQ(100_000_000),
        .BAUD(9600)
    ) u_tx (
        .clk(PCLK),
        .arst_n(PRESETn),
        .tx_en(|tx_data),   
        .tx_data(tx_data),
        .tx(tx_serial),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

  
    UART_RX u_rx (
        .clk(PCLK),
        .arst_n(PRESETn),
        .rx_en(1'b1),
        .rx(tx_serial),    // Loopback connection
        .rx_busy(rx_busy),
        .rx_error(rx_error),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // Clock generation
    initial PCLK = 0;
    always #5 PCLK = ~PCLK;  

 
    task apb_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge PCLK);
        PSEL   <= 1;
        PWRITE <= 1;
        PADDR  <= addr;
        PWDATA <= data;
        PENABLE<= 0;

        @(posedge PCLK);
        PENABLE <= 1;

        @(posedge PCLK);
        while (!PREADY) @(posedge PCLK);

        @(posedge PCLK);
        PSEL   <= 0;
        PENABLE<= 0;
        PWRITE <= 0;
    end
    endtask

  
    task apb_read(input [31:0] addr);
    begin
        @(posedge PCLK);
        PSEL   <= 1;
        PWRITE <= 0;
        PADDR  <= addr;
        PENABLE<= 0;

        @(posedge PCLK);
        PENABLE <= 1;  

        @(posedge PCLK);
        while (!PREADY) @(posedge PCLK);

        $display("[%0t] APB READ @%h = %h", $time, addr, PRDATA);
        @(posedge PCLK);
        PSEL   <= 0;
        PENABLE<= 0;
    end
    endtask

  
    initial begin
        // Init
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = 0;
        PWDATA  = 0;

        PRESETn = 0;
        repeat(3) @(posedge PCLK);
        PRESETn = 1;

       

        // Write to CTRL register
        apb_write(32'h0000, 32'h1);  
        apb_read(32'h0000);

        //tx=51
        apb_write(32'h0002, 32'h51);
        apb_read(32'h0002);

        // Wait for TX-RX transfer
        repeat(90000) @(posedge PCLK);

        //  equal 0x51 rx_data
        apb_read(32'h0003);

        // Read STATUS
        wait(PREADY);
        apb_read(32'h0001);

      
        $stop;
    end

endmodule
