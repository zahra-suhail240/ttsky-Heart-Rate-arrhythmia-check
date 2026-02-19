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

  clock_divider u_divider ( );

  interval_detection u_interval ();

  live_arrhythmia_comparator u_live_comp ();

  final_analysis_comparator u_final ();


endmodule


/*
SUB-MODULES
You can define sub-modules here. Make sure to connect them properly in the main module above
*/

module clock_divider ();

 

endmodule


module interval_detection ();
          


endmodule


module live_arrhythmia_comparator ();

   

endmodule


module final_analysis_comparator ();



endmodule
