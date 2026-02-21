/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_Heart_Rate_arrhythmia_check (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

  // Instantiate sub-modules here and connect them as needed (you define the ports)
 
 wire clk_div;
 wire [11:0] rr_interval_ms;     // latest RR interval (ms)
  wire new_rr;             // high for 1 cycle when new RR ready

  clock_divider u_divider ();

  interval_detection u_interval (.clk_div(clk_div),
                                  .rst_n (rst_n),
                                  .pulse_in (ui_in[0]),           // heartbeat pulse input
                                  .rr_interval_ms (rr_interval_ms),
                                  .new_rr_pulse (new_rr));

  live_arrhythmia_comparator u_live_comp ();
  

  wire        rst = ~rst_n;          // final_analyzer uses active-high reset
  wire        rr_valid = new_rr;     // new RR interval ready
  wire        force_anlz = ui_in[1]; 

  wire [1:0] final_diag;
  wire       diag_valid;
  wire [7:0] confidence;

  final_analyzer u_final_analyzer (
      .clk         (clk_div),       // or use clk if you prefer
      .rst         (rst),
      .rr_valid    (rr_valid),
      .live_brady  (live_brady),
      .live_tachy  (live_tachy),
      .live_irreg  (live_irreg),
      .live_normal (live_normal),
      .force_anlz  (force_anlz),
      .final_diag  (final_diag),
      .diag_valid  (diag_valid),
      .confidence  (confidence)
  );


endmodule


/*
SUB-MODULES
You can define sub-modules here. Make sure to connect them properly in the main module above
*/

module clock_divider ();

 



endmodule


module interval_detection (input  wire  clk_div,       //clock_divider
                            input  wire rst_n,
                            input  wire pulse_in,      // heartbeat pulse (e.g. ui_in[0] – assume rising edge per beat)
                            output reg  [11:0] rr_interval_ms, // most recent RR in milliseconds
                            output reg  new_rr_pulse   // high for 1 cycle when new RR is ready
    );
          

reg pulse_prev;
    wire rising_edge = pulse_in & ~pulse_prev;

    reg [11:0] counter;  // time since last beat

    always @(posedge clk_div or negedge rst_n) begin
        if (!rst_n) begin
            pulse_prev     <= 1'b0;
            counter        <= 12'd0;
            rr_interval_ms <= 12'd0;
            new_rr_pulse   <= 1'b0;
        end else begin
            pulse_prev     <= pulse_in;
            new_rr_pulse   <= 1'b0;

            if (rising_edge) begin
                rr_interval_ms <= counter;
                counter        <= 12'd0;
                new_rr_pulse   <= 1'b1;
            end else if (counter != 12'hFFF) begin
                counter <= counter + 1'b1;   // saturate at 4095 ms (~15 bpm)
            end
        end
    end

endmodule


module live_arrhythmia_comparator ();

   

endmodule


module final_analysis_comparator ();



endmodule

// ============================================================
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