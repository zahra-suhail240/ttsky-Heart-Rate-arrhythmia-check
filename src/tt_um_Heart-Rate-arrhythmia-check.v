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
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // 50 MHz clock
    input  wire       rst_n     // active-low reset
);

  // -------------------------------------------------------------------------
  // Internal wires
  // -------------------------------------------------------------------------
  wire        clk_div;          // 1 kHz clock from clock divider

  wire [11:0] rr_interval_ms;   // latest RR interval in milliseconds
  wire        new_rr;           // 1-cycle strobe when new RR is ready

  wire        tachy_flag;       // live classification flags from arrhythmia_compare
  wire        normal_flag;
  wire        brady_flag;
  wire [1:0]  type_code;
  wire [15:0] total_beats;
  wire [15:0] tachy_count;
  wire [15:0] normal_count;
  wire [15:0] brady_count;

  wire        irreg_flag;       // live irregularity flag from irregularity_detector
  wire [15:0] irreg_count;      // running count of irregular beats

  wire        rst        = ~rst_n;      // active-high reset for final_analyzer
  wire        force_anlz = ui_in[1];    // manual force-analysis trigger

  wire [1:0]  final_diag;   // 00=Normal 01=Brady 10=Tachy 11=Irregular
  wire        diag_valid;   // high when diagnosis result is ready
  wire [7:0]  confidence;   // 0-255 confidence score

  // Output assignments
  // uo_out[0]   = tachy live flag
  // uo_out[1]   = normal live flag
  // uo_out[2]   = brady live flag
  // uo_out[3]   = irreg live flag
  // uo_out[5:4] = final_diag
  // uo_out[6]   = diag_valid
  // uo_out[7]   = unused
  // uio_out     = confidence score (0-255)
  assign uo_out[0]   = tachy_flag;
  assign uo_out[1]   = normal_flag;
  assign uo_out[2]   = brady_flag;
  assign uo_out[3]   = irreg_flag;
  assign uo_out[5:4] = final_diag;
  assign uo_out[6]   = diag_valid;
  assign uo_out[7]   = 1'b0;

  assign uio_out = confidence;
  assign uio_oe  = 8'hFF;       // all bidir pins as outputs

  // Suppress unused input warnings
  wire _unused = &{ena, uio_in, ui_in[7:2], type_code,
                   total_beats, tachy_count, normal_count,
                   brady_count, irreg_count, 1'b0};

  clock_dividerms u_clkdiv (
    .clk     (clk),
    .rst_n   (rst_n),
    .clk_div (clk_div)
  );

  interval_detection u_interval (
    .clk_div       (clk_div),
    .rst_n         (rst_n),
    .pulse_in      (ui_in[0]),
    .rr_interval_ms(rr_interval_ms),
    .new_rr_pulse  (new_rr)
  );

  arrhythmia_compare u_arrhythmia_compare (
    .clk           (clk_div),
    .rst_n         (rst_n),
    .rr_interval_ms(rr_interval_ms),
    .new_rr_pulse  (new_rr),
    .type_code     (type_code),
    .tachy_flag    (tachy_flag),
    .normal_flag   (normal_flag),
    .brady_flag    (brady_flag),
    .total_beats   (total_beats),
    .tachy_count   (tachy_count),
    .normal_count  (normal_count),
    .brady_count   (brady_count)
  );

  irregularity_detector u_irreg (
    .clk_div       (clk_div),
    .rst_n         (rst_n),
    .rr_interval_ms(rr_interval_ms),
    .new_rr_pulse  (new_rr),
    .irreg_flag    (irreg_flag),
    .irreg_count   (irreg_count)
  );

  final_analyzer u_final_analyzer (
    .clk        (clk_div),
    .rst        (rst),
    .rr_valid   (new_rr),
    .live_brady (brady_flag),
    .live_tachy (tachy_flag),
    .live_irreg (irreg_flag),
    .live_normal(normal_flag),
    .force_anlz (force_anlz),
    .final_diag (final_diag),
    .diag_valid (diag_valid),
    .confidence (confidence)
  );

endmodule