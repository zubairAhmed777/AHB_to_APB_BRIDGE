`timescale 1ns / 1ps

module apb_controller3 (
    input  wire        HCLK,
    input  wire        HRESETn,

    input  wire        valid,        // accepted AHB transfer this cycle
    input  wire        hwrite,       // current HWRITE
    input  wire        hwrite_reg,   // HWRITE of the latest accepted transfer
    input  wire [31:0] haddr_q,      // address of latest accepted transfer
    input  wire [31:0] haddr_q2,     // address of the one before it
    input  wire [2:0]  selx_q,
    input  wire [2:0]  selx_q2,
    input  wire [31:0] hwdata_q,
    input  wire [31:0] prdata,

    output reg  [31:0] paddr,
    output reg  [31:0] pwdata,
    output reg         pwrite,
    output reg  [2:0]  psel,
    output reg         penable,
    output reg         hready_out,
    output wire [31:0] hrdata
);

    //----------------------------------------------------------
    // States
    //----------------------------------------------------------
    localparam ST_IDLE     = 3'd0,
               ST_READ     = 3'd1,
               ST_RENABLE  = 3'd2,
               ST_WWAIT    = 3'd3,
               ST_WRITE    = 3'd4,
               ST_WRITEP   = 3'd5,
               ST_WENABLE  = 3'd6,
               ST_WENABLEP = 3'd7;

    reg [2:0]  p_state, n_state;

    // Hold registers: repeat the setup-phase APB values in the enable phase
    reg [31:0] paddr_r, pwdata_r;
    reg [2:0]  sel_r;
    reg        pwrite_r;

    reg [2:0]  sel;
    reg        psel_en;

    //----------------------------------------------------------
    // Present state
    //----------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) p_state <= ST_IDLE;
        else          p_state <= n_state;
    end

    //----------------------------------------------------------
    // Next state
    //----------------------------------------------------------
    always @(*) begin
        n_state = p_state;
        case (p_state)
            ST_IDLE, ST_RENABLE, ST_WENABLE: begin
                if      (valid && ~hwrite) n_state = ST_READ;
                else if (valid &&  hwrite) n_state = ST_WWAIT;
                else                       n_state = ST_IDLE;
            end
            ST_READ:     n_state = ST_RENABLE;
            ST_WWAIT:    n_state = valid ? ST_WRITEP   : ST_WRITE;
            ST_WRITE:    n_state = valid ? ST_WENABLEP : ST_WENABLE;
            ST_WRITEP:   n_state = ST_WENABLEP;
            ST_WENABLEP: begin
                if      (~hwrite_reg) n_state = ST_READ;
                else if (valid)       n_state = ST_WRITEP;
                else                  n_state = ST_WRITE;
            end
            default:     n_state = ST_IDLE;
        endcase
    end

    //----------------------------------------------------------
    // Outputs (combinational from state; hold values by default)
    //----------------------------------------------------------
    always @(*) begin
        paddr      = paddr_r;
        pwdata     = pwdata_r;
        pwrite     = pwrite_r;
        sel        = sel_r;
        psel_en    = 1'b0;
        penable    = 1'b0;
        hready_out = 1'b1;

        case (p_state)
            ST_IDLE, ST_WWAIT: begin
                // no APB activity, bus ready
            end

            ST_READ: begin                       // APB setup, read
                paddr      = haddr_q;
                sel        = selx_q;
                pwrite     = 1'b0;
                psel_en    = 1'b1;
                hready_out = 1'b0;
            end

            ST_RENABLE: begin                    // APB access, read
                psel_en    = 1'b1;
                penable    = 1'b1;
            end

            ST_WRITE: begin                      // APB setup, write (no pending)
                paddr      = haddr_q;
                sel        = selx_q;
                pwdata     = hwdata_q;
                pwrite     = 1'b1;
                psel_en    = 1'b1;
                hready_out = 1'b0;
            end

            ST_WRITEP: begin                     // APB setup, write (next pending)
                paddr      = haddr_q2;
                sel        = selx_q2;
                pwdata     = hwdata_q;
                pwrite     = 1'b1;
                psel_en    = 1'b1;
                hready_out = 1'b0;
            end

            ST_WENABLE: begin                    // APB access, write
                psel_en    = 1'b1;
                penable    = 1'b1;
            end

            ST_WENABLEP: begin                   // APB access, write (next pending)
                psel_en    = 1'b1;
                penable    = 1'b1;
                hready_out = hwrite_reg;         // pending read -> keep AHB stalled
            end
        endcase

        psel = psel_en ? sel : 3'b000;
    end

    //----------------------------------------------------------
    // Hold registers
    //----------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            paddr_r  <= 32'b0;
            pwdata_r <= 32'b0;
            pwrite_r <= 1'b0;
            sel_r    <= 3'b000;
        end else begin
            paddr_r  <= paddr;
            pwdata_r <= pwdata;
            pwrite_r <= pwrite;
            sel_r    <= sel;
        end
    end

    //----------------------------------------------------------
    // Read data: valid in ST_RENABLE, when hready_out = 1
    //----------------------------------------------------------
    assign hrdata = prdata;

endmodule
