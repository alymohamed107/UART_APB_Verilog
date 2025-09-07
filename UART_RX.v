module UART_RX (
    input  wire       clk,
    input  wire       arst_n,
    input  wire       rx_en,
    input  wire       rx,
    output reg        rx_busy,
    output reg        rx_error,
    output reg [7:0]  rx_data,
    output reg        rx_done
);

    // FSM states
    localparam IDLE  = 3'b000,
               START = 3'b001,
               DATA  = 3'b010,
               STOP  = 3'b011,
               DONE  = 3'b100,
               ERR   = 3'b101;

    reg [2:0] ps, ns;   
    reg [20:0] tick_load;
    wire       tick_FSM;
    reg [2:0]  bit_counter;
    reg [7:0]  rx_shift_reg;
    reg        rx_d1;

    // UART baud counter
    baud_counter bc (
        .clk(clk),
        .rst(~arst_n),
        .load_val(tick_load),
        .tick_FSM(tick_FSM)
    );

    // Edge detection for start bit (falling edge)
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            rx_d1 <= 1'b1;  // idle high
        else
            rx_d1 <= rx;
    end
    wire start_edge = (~rx & rx_d1);

    // Sequential logic
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            ps          <= IDLE;
            rx_busy     <= 0;
            rx_error    <= 0;
            rx_done     <= 0;
            rx_data     <= 0;
            rx_shift_reg<= 0;
            bit_counter <= 0;
            tick_load   <= 0;
        end else begin
            ps <= ns; 

            case (ps)
                IDLE: begin
                    rx_done  <= 0;
                    rx_error <= 0;
                    if (rx_en && start_edge) begin
                        rx_busy   <= 1;
                        tick_load <= 10416 + (10416/2); // 1.5 bit delay
                        bit_counter <= 0;
                    end else begin
                        rx_busy <= 0;
                    end
                end

                START: begin
                    if (tick_FSM) begin
                        tick_load   <= 10416; // 1 bit period
                        bit_counter <= 0;
                    end
                end

                DATA: begin
                    if (tick_FSM) begin
                        rx_shift_reg[bit_counter] <= rx;
                        if (bit_counter == 3'd7) begin
                            tick_load <= 10416; // prepare for stop bit
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end

                STOP: begin
                    if (tick_FSM) begin
                        if (rx) begin
                            rx_busy <= 0;
                        end else begin
                            rx_error <= 1; // framing error
                            rx_busy  <= 0;
                        end
                    end
                end

                DONE: begin
                    rx_done <= 1;
                    rx_data <= rx_shift_reg;
                    rx_busy <= 0;
                end

                ERR: begin
                    rx_error <= 1;
                    rx_busy  <= 0;
                end
            endcase
        end
    end

    // Next-state logic
    always @(*) begin
        ns = ps;
        case (ps)
            IDLE:  ns = (rx_en && start_edge) ? START : IDLE;
            START: ns = (tick_FSM) ? DATA : START;
            DATA:  ns = (tick_FSM && bit_counter == 3'd7) ? STOP : DATA;
            STOP:  ns = (tick_FSM) ? (rx ? DONE : ERR) : STOP;
            DONE:  ns = IDLE;
            ERR:   ns = IDLE;
        endcase
    end

endmodule