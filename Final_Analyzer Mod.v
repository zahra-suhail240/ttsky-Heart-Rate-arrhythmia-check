/ ============================================================
// Final Analyzer
// Accumulates counts of brady/tachy/irreg/normal over last
// 8 beats, then selects dominant condition and a confidence
// score (0-255 mapped from 0-8 beats).
//
// Final diagnosis encoding:
//   2'b00 = Normal
//   2'b01 = Bradycardia
//   2'b10 = Tachycardia
//   2'b11 = Irregular
//
// Confidence = (dominant_count / 8) * 255
// Approximated as dominant_count * 32 (max 256, capped at 255)
// ============================================================
module final_analyzer (
    input  wire        clk,
    input  wire        rst,
    input  wire        rr_valid,
    input  wire        live_brady,
    input  wire        live_tachy,
    input  wire        live_irreg,
    input  wire        live_normal,
    input  wire        force_anlz,
    output reg  [1:0]  final_diag,
    output reg         diag_valid,
    output reg  [7:0]  confidence
);
    // Rolling window: 8 beats, store type per beat
    // Types: 2'b00=Normal, 2'b01=Brady, 2'b10=Tachy, 2'b11=Irreg
    reg [1:0] type_fifo [0:7];
    reg [2:0] wr_ptr;
    reg [3:0] fill_cnt;

    // Counts
    reg [3:0] cnt_normal, cnt_brady, cnt_tachy, cnt_irreg;

    // Edge detect on force_anlz
    reg force_prev;
    wire force_pulse = force_anlz && !force_prev;

    integer i;
    reg [3:0] dom_count;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr     <= 3'd0;
            fill_cnt   <= 4'd0;
            final_diag <= 2'b00;
            diag_valid <= 1'b0;
            confidence <= 8'd0;
            force_prev <= 1'b0;
            cnt_normal <= 4'd0;
            cnt_brady  <= 4'd0;
            cnt_tachy  <= 4'd0;
            cnt_irreg  <= 4'd0;
            for (i = 0; i < 8; i = i + 1)
                type_fifo[i] <= 2'b00;
        end else begin
            force_prev <= force_anlz;

            if (rr_valid) begin
                // Classify and store
                if (live_irreg)
                    type_fifo[wr_ptr] <= 2'b11;
                else if (live_brady)
                    type_fifo[wr_ptr] <= 2'b01;
                else if (live_tachy)
                    type_fifo[wr_ptr] <= 2'b10;
                else
                    type_fifo[wr_ptr] <= 2'b00;

                wr_ptr <= wr_ptr + 3'd1;
                if (fill_cnt < 4'd8)
                    fill_cnt <= fill_cnt + 4'd1;

                // Recount all 8 slots
                cnt_normal = 4'd0;
                cnt_brady  = 4'd0;
                cnt_tachy  = 4'd0;
                cnt_irreg  = 4'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    case (type_fifo[i])
                        2'b01: cnt_brady  = cnt_brady  + 4'd1;
                        2'b10: cnt_tachy  = cnt_tachy  + 4'd1;
                        2'b11: cnt_irreg  = cnt_irreg  + 4'd1;
                        default: cnt_normal = cnt_normal + 4'd1;
                    endcase
                end

                // Auto-analyze after 8 beats
                if (fill_cnt == 4'd8 || force_pulse) begin
                    diag_valid <= 1'b1;

                    // Find dominant (priority: irreg > tachy > brady > normal)
                    if (cnt_irreg >= cnt_brady && cnt_irreg >= cnt_tachy && cnt_irreg >= cnt_normal) begin
                        final_diag <= 2'b11;
                        dom_count   = cnt_irreg;
                    end else if (cnt_tachy >= cnt_brady && cnt_tachy >= cnt_normal) begin
                        final_diag <= 2'b10;
                        dom_count   = cnt_tachy;
                    end else if (cnt_brady >= cnt_normal) begin
                        final_diag <= 2'b01;
                        dom_count   = cnt_brady;
                    end else begin
                        final_diag <= 2'b00;
                        dom_count   = cnt_normal;
                    end

                    // Confidence: dom_count * 32 = dom_count << 5, cap at 255
                    // dom_count max = 8; 8*32=256 → cap to 255
                    if (dom_count == 4'd8)
                        confidence <= 8'hFF;
                    else
                        confidence <= {1'b0, dom_count[3:0], 3'b000};  // *8 as rough scale
                end
            end else if (force_pulse && fill_cnt >= 4'd4) begin
                // Allow forced analysis with at least 4 beats
                diag_valid <= 1'b1;
            end
        end
    end
endmodule