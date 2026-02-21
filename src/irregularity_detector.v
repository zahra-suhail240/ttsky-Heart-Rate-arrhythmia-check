// ============================================================
// irregularity_detector.v
// ============================================================
// Detects irregular heart rhythms by measuring beat-to-beat
// RR interval variation over a sliding window of 4 beats.
//
// Clock domain : clk_div (1 kHz — 1 tick = 1 ms)
// RR unit      : milliseconds (12-bit, matches interval_detection)
// Reset        : active-low rst_n (matches rest of design)
//
// Algorithm:
//   On each new_rr_pulse, store the incoming rr_interval_ms
//   into a 4-entry circular FIFO. After at least 2 entries are
//   filled, compute the absolute difference between the current
//   RR and the previous RR (successive difference). If this
//   difference exceeds IRREG_THRESH_MS, assert irreg_flag for
//   one clock cycle and increment irreg_count.
//
// Threshold:
//   IRREG_THRESH_MS = 200 ms
//   Clinically, beat-to-beat variation > 200 ms is a strong
//   indicator of atrial fibrillation or other irregular rhythms.
//   Normal sinus rhythm varies by < 50 ms beat-to-beat.
//
// Outputs:
//   irreg_flag   — high for 1 cycle when current beat is irregular
//   irreg_count  — running total of irregular beats detected
// ============================================================

`default_nettype none

module irregularity_detector #(
    parameter IRREG_THRESH_MS = 12'd200   // 200 ms beat-to-beat variation threshold
) (
    input  wire        clk_div,         // 1 kHz clock (1 tick = 1 ms)
    input  wire        rst_n,           // active-low reset

    input  wire [11:0] rr_interval_ms,  // current RR interval from interval_detection
    input  wire        new_rr_pulse,    // 1-cycle strobe when rr_interval_ms is valid

    output reg         irreg_flag,      // high for 1 cycle when beat is irregular
    output reg  [15:0] irreg_count      // total count of irregular beats
);

    // --------------------------------------------------------
    // 4-entry FIFO of recent RR intervals
    // --------------------------------------------------------
    reg [11:0] rr_fifo [0:3];
    reg [1:0]  wr_ptr;       // write pointer (wraps 0-3)
    reg [2:0]  fill_cnt;     // how many entries filled (0-4)

    // --------------------------------------------------------
    // Previous RR interval (the entry just before current)
    // --------------------------------------------------------
    wire [11:0] rr_prev = rr_fifo[(wr_ptr == 2'd0) ? 2'd3 : wr_ptr - 2'd1];

    // --------------------------------------------------------
    // Absolute difference between current and previous RR
    // --------------------------------------------------------
    wire [11:0] rr_diff = (rr_interval_ms > rr_prev)
                          ? (rr_interval_ms - rr_prev)
                          : (rr_prev - rr_interval_ms);

    integer i;

    always @(posedge clk_div or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr      <= 2'd0;
            fill_cnt    <= 3'd0;
            irreg_flag  <= 1'b0;
            irreg_count <= 16'd0;
            for (i = 0; i < 4; i = i + 1)
                rr_fifo[i] <= 12'd0;
        end else begin

            irreg_flag <= 1'b0;   // default: no irregularity this cycle

            if (new_rr_pulse) begin

                // Store new RR interval into FIFO
                rr_fifo[wr_ptr] <= rr_interval_ms;
                wr_ptr          <= wr_ptr + 2'd1;  // wraps automatically (2-bit)

                if (fill_cnt < 3'd4)
                    fill_cnt <= fill_cnt + 3'd1;

                // Only compare once we have at least 2 entries
                // (need a current and a previous to diff against)
                if (fill_cnt >= 3'd2) begin
                    if (rr_diff > IRREG_THRESH_MS) begin
                        irreg_flag  <= 1'b1;
                        irreg_count <= irreg_count + 16'd1;
                    end
                end

            end
        end
    end

endmodule