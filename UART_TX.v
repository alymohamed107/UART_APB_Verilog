module UART_TX #(
    parameter CLK_FREQ = 100_000_000,   // 100 MHz
    parameter BAUD     = 9600,
    parameter DIV      = CLK_FREQ / BAUD
)(
    input  wire       clk,
    input  wire       arst_n,
    input  wire       tx_en,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);

    // Internal
    reg [9:0] frame;        
    reg [3:0] bit_cnt;      
    reg [20:0] tick_load;   
    wire       tick_FSM;    

    
    baud_counter bc (
        .clk(clk),
        .rst(~arst_n),
        .load_val(tick_load),
        .tick_FSM(tick_FSM)
    );

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            frame     <= 10'b0;
            bit_cnt   <= 0;
            tx        <= 1'b1;
            tx_busy   <= 0;
            tx_done   <= 0;
            tick_load <= 0;
        end else begin
            tx_done <= 0; 

            if (tx_en && !tx_busy) begin
               
                frame     <= {1'b1, tx_data, 1'b0};
                bit_cnt   <= 0;
                tx_busy   <= 1;
                tick_load <= DIV-1; 
            end else if (tx_busy) begin
                if (tick_FSM) begin
                  
                    tx      <= frame[bit_cnt];
                    bit_cnt <= bit_cnt + 1;

                    if (bit_cnt == 9) begin
                        tx_busy   <= 0;
                        tx_done   <= 1;
                        tick_load <= 0;  
                    end else begin
                        tick_load <= DIV-1; // reload for next bit
                    end
                end
            end
        end
    end

endmodule
