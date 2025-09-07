module APB (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output reg         PREADY,

    output reg  [3:0]  ctrl_reg,
    input  wire        rx_done,
    input  wire        tx_done,
    input  wire        tx_busy,
    input  wire        rx_error,
    input  wire        rx_busy,
    input  wire [7:0]  rx_data,
    output reg  [7:0]  tx_data
);

    // Register definitions
    localparam CTRL_REG_ADDR = 32'h0000;
    localparam STAT_REG_ADDR = 32'h0001;
    localparam TX_DATA_ADDR  = 32'h0002;
    localparam RX_DATA_ADDR  = 32'h0003;

    // Registers to hold internal state
    reg [4:0] stat_reg;
    reg [7:0] rx_data_reg;

 
    reg apb_fsm_state;
    localparam STATE_IDLE  = 1'b0;
    localparam STATE_SETUP = 1'b1;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            apb_fsm_state <= STATE_IDLE;
            PREADY        <= 1'b0;
        end else begin
            case (apb_fsm_state)
                STATE_IDLE: begin
                    if (PSEL) begin
                        apb_fsm_state <= STATE_SETUP;
                    end
                    PREADY <= 1'b0;
                end
                STATE_SETUP: begin
                    if (PSEL && PENABLE) begin
                        apb_fsm_state <= STATE_IDLE;
                        PREADY        <= 1'b1; 
                    end else if (!PSEL) begin
                        apb_fsm_state <= STATE_IDLE;
                    end
                end
                default: apb_fsm_state <= STATE_IDLE;
            endcase
        end
    end
    

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ctrl_reg    <= 0;
            tx_data     <= 0;
            rx_data_reg <= 0;
            stat_reg    <= 0;
        end else if (PSEL && PENABLE && PREADY) begin 
            // APB Write
            if (PWRITE) begin
                case (PADDR)
                    CTRL_REG_ADDR: ctrl_reg <= PWDATA[3:0];
                    TX_DATA_ADDR:  tx_data  <= PWDATA[7:0];
                endcase
            end
            // Latch UART Rx Data
            if (rx_done) begin
                rx_data_reg <= rx_data;
            end
            // Latch UART Status
            stat_reg <= {rx_busy, rx_done, rx_error, tx_busy, tx_done};
        end else begin
             if (rx_done) begin
                rx_data_reg <= rx_data;
            end
            stat_reg <= {rx_busy, rx_done, rx_error, tx_busy, tx_done};
        end
    end

    // --- Read Data Logic (Combinational) ---
    always @(*) begin
        case (PADDR)
            CTRL_REG_ADDR: PRDATA = {28'h0, ctrl_reg};
            STAT_REG_ADDR: PRDATA = {27'h0, stat_reg};
            TX_DATA_ADDR:  PRDATA = {24'h0, tx_data};
            RX_DATA_ADDR:  PRDATA = {24'h0, rx_data_reg};
            default: PRDATA = 32'h0;
        endcase
    end
endmodule
