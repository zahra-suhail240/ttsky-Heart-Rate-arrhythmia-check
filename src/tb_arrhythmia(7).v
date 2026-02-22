// ============================================================
// Testbench for Heart Rate Arrhythmia Checker
// ============================================================
// Run in ModelSim:
//   vlib work
//   vlog heart_rate_design.v
//   vlog tb_arrhythmia.v
//   vsim work.tb_top_level
//   run -all
//
// Individual module tests:
//   vsim work.tb_clock_dividerms    -> run -all
//   vsim work.tb_interval_detection -> run -all
//   vsim work.tb_arrhythmia_compare -> run -all
//   vsim work.tb_irregularity_detector -> run -all
//   vsim work.tb_final_analyzer     -> run -all
// ============================================================

`timescale 1ns/1ps

// ============================================================
// dut_fast: top-level wrapper with DIV=2 for fast simulation
// FIXED: final_analyzer now uses rst_n (active-low) to match
//        every other module. Removed the wire rst = ~rst_n.
// ============================================================
module dut_fast (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire        clk_div;
    wire [11:0] rr_interval_ms;
    wire        new_rr;
    wire        tachy_flag, normal_flag, brady_flag;
    wire [1:0]  type_code;
    wire [15:0] total_beats, tachy_count, normal_count, brady_count;
    wire        irreg_flag;
    wire [15:0] irreg_count;
    wire        force_anlz = ui_in[1];
    wire [1:0]  final_diag;
    wire        diag_valid;
    wire [7:0]  confidence;

    assign uo_out[0]   = tachy_flag;
    assign uo_out[1]   = normal_flag;
    assign uo_out[2]   = brady_flag;
    assign uo_out[3]   = irreg_flag;
    assign uo_out[5:4] = final_diag;
    assign uo_out[6]   = diag_valid;
    assign uo_out[7]   = 1'b0;
    assign uio_out = confidence;
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, ui_in[7:2], type_code,
                     total_beats, tachy_count, normal_count,
                     brady_count, irreg_count, 1'b0};

    // DIV=2 so simulation runs fast — logic identical to real design
    clock_dividerms #(.DIV(2)) u_clkdiv (
        .clk(clk), .rst_n(rst_n), .clk_div(clk_div)
    );
    interval_detection u_interval (
        .clk_div(clk_div), .rst_n(rst_n), .pulse_in(ui_in[0]),
        .rr_interval_ms(rr_interval_ms), .new_rr_pulse(new_rr)
    );
    arrhythmia_compare u_arrhythmia_compare (
        .clk(clk_div), .rst_n(rst_n),
        .rr_interval_ms(rr_interval_ms), .new_rr_pulse(new_rr),
        .type_code(type_code), .tachy_flag(tachy_flag),
        .normal_flag(normal_flag), .brady_flag(brady_flag),
        .total_beats(total_beats), .tachy_count(tachy_count),
        .normal_count(normal_count), .brady_count(brady_count)
    );
    irregularity_detector u_irreg (
        .clk_div(clk_div), .rst_n(rst_n),
        .rr_interval_ms(rr_interval_ms), .new_rr_pulse(new_rr),
        .irreg_flag(irreg_flag), .irreg_count(irreg_count)
    );
    // FIXED: pass rst_n directly — final_analyzer uses active-low reset
    final_analyzer u_final_analyzer (
        .clk(clk_div), .rst_n(rst_n), .rr_valid(new_rr),
        .live_brady(brady_flag), .live_tachy(tachy_flag),
        .live_irreg(irreg_flag), .live_normal(normal_flag),
        .force_anlz(force_anlz), .final_diag(final_diag),
        .diag_valid(diag_valid), .confidence(confidence)
    );
endmodule


// ============================================================
// TB1 - clock_dividerms
// ============================================================
module tb_clock_dividerms;
    reg  clk, rst_n;
    wire clk_div;

    clock_dividerms #(.DIV(25000)) dut (
        .clk(clk), .rst_n(rst_n), .clk_div(clk_div)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    integer errors, rise_time, full_period;

    initial begin
        $display("========================================");
        $display("TB1: clock_dividerms");
        $display("========================================");
        errors = 0;
        rst_n = 0;
        repeat(20) @(posedge clk);
        rst_n = 1; #1;

        if (clk_div !== 1'b0) begin
            $display("  [FAIL] clk_div not 0 after reset"); errors = errors + 1;
        end else $display("  [PASS] clk_div=0 after reset");

        @(posedge clk_div); rise_time = $time;
        @(posedge clk_div);
        full_period = $time - rise_time;
        $display("  [INFO] period=%0d ns (expect 1000000)", full_period);
        if (full_period < 999000 || full_period > 1001000) begin
            $display("  [FAIL] Period out of range"); errors = errors + 1;
        end else $display("  [PASS] Period correct (~1ms)");

        rst_n = 0; repeat(20) @(posedge clk); #1;
        if (clk_div !== 1'b0) begin
            $display("  [FAIL] mid-run reset did not clear clk_div"); errors = errors + 1;
        end else $display("  [PASS] mid-run reset clears clk_div");
        rst_n = 1;

        if (errors == 0) $display("  [PASS] clock_dividerms: all passed");
        else             $display("  [FAIL] clock_dividerms: %0d error(s)", errors);
        $display(""); $finish;
    end
endmodule


// ============================================================
// TB2 - interval_detection
// Driven directly at 1 tick = 1ms (bypasses clock divider)
// NOTE: debounce = 10 ticks, so send_beat holds pulse HIGH
//       for 12 ticks to guarantee debounce passes.
// ============================================================
module tb_interval_detection;
    reg        clk, rst_n, pulse_in;
    wire [11:0] rr_interval_ms;
    wire        new_rr_pulse;

    interval_detection dut (
        .clk_div(clk), .rst_n(rst_n), .pulse_in(pulse_in),
        .rr_interval_ms(rr_interval_ms), .new_rr_pulse(new_rr_pulse)
    );

    initial clk = 0;
    always #500 clk = ~clk;

    integer errors;

    task do_reset;
        begin
            rst_n = 0; pulse_in = 0;
            repeat(5) @(posedge clk);
            rst_n = 1; @(posedge clk); #1;
        end
    endtask

    // Hold pulse HIGH for 15 ticks (> DEBOUNCE_MS=10) then release
    task send_beat;
        begin
            @(posedge clk); #1; pulse_in = 1;
            repeat(15) @(posedge clk); #1;
            pulse_in = 0;
            repeat(5) @(posedge clk); // gap
        end
    endtask

    task wait_ticks;
        input integer n; integer i;
        begin for (i=0;i<n;i=i+1) @(posedge clk); end
    endtask

    initial begin
        $display("========================================");
        $display("TB2: interval_detection");
        $display("========================================");
        errors = 0; do_reset;

        // 2a: No pulse → new_rr_pulse stays 0
        wait_ticks(5);
        if (new_rr_pulse !== 1'b0) begin
            $display("  [FAIL] 2a: new_rr_pulse should be 0"); errors=errors+1;
        end else $display("  [PASS] 2a: new_rr_pulse=0 before beats");

        // 2b: First beat only - no RR output yet
        send_beat; wait_ticks(2);
        if (new_rr_pulse !== 1'b0) begin
            $display("  [FAIL] 2b: should be 0 after 1 beat"); errors=errors+1;
        end else $display("  [PASS] 2b: no output after first beat");

        // 2c: ~800ms interval (accounting for debounce time in beat)
        wait_ticks(779); send_beat;
        wait_ticks(10);
        if (new_rr_pulse !== 1'b1) begin
            $display("  [FAIL] 2c: new_rr_pulse not high"); errors=errors+1;
        end else begin
            $display("  [INFO] 2c: rr=%0d (expect ~800)", rr_interval_ms);
            if (rr_interval_ms < 780 || rr_interval_ms > 820) begin
                $display("  [FAIL] 2c: out of range"); errors=errors+1;
            end else $display("  [PASS] 2c: ~800ms correct");
        end

        // 2d: Pulse 1 cycle wide
        wait_ticks(2);
        if (new_rr_pulse !== 1'b0) begin
            $display("  [FAIL] 2d: pulse should clear"); errors=errors+1;
        end else $display("  [PASS] 2d: new_rr_pulse 1 cycle wide");

        // 2e: ~400ms interval
        do_reset; send_beat; wait_ticks(379); send_beat;
        wait_ticks(10);
        $display("  [INFO] 2e: rr=%0d (expect ~400)", rr_interval_ms);
        if (rr_interval_ms < 380 || rr_interval_ms > 420) begin
            $display("  [FAIL] 2e: ~400ms wrong"); errors=errors+1;
        end else $display("  [PASS] 2e: ~400ms correct");

        // 2f: Saturation at 4095ms
        do_reset; send_beat; wait_ticks(5000); send_beat;
        wait_ticks(10);
        $display("  [INFO] 2f: rr=%0d (expect 4095)", rr_interval_ms);
        if (rr_interval_ms !== 12'hFFF) begin
            $display("  [FAIL] 2f: no saturation"); errors=errors+1;
        end else $display("  [PASS] 2f: saturates at 4095");

        // 2g: ~1000ms interval
        do_reset; send_beat; wait_ticks(979); send_beat;
        wait_ticks(10);
        $display("  [INFO] 2g: rr=%0d (expect ~1000)", rr_interval_ms);
        if (rr_interval_ms < 980 || rr_interval_ms > 1020) begin
            $display("  [FAIL] 2g: ~1000ms wrong"); errors=errors+1;
        end else $display("  [PASS] 2g: ~1000ms correct");

        if (errors==0) $display("  [PASS] interval_detection: all passed");
        else           $display("  [FAIL] interval_detection: %0d error(s)", errors);
        $display(""); $finish;
    end
endmodule


// ============================================================
// TB3 - arrhythmia_compare
// Drives rr_interval_ms directly — no debounce involved
// ============================================================
module tb_arrhythmia_compare;
    reg        clk, rst_n;
    reg [11:0] rr_interval_ms;
    reg        new_rr_pulse;
    wire [1:0]  type_code;
    wire        tachy_flag, normal_flag, brady_flag;
    wire [15:0] total_beats, tachy_count, normal_count, brady_count;

    arrhythmia_compare dut (
        .clk(clk), .rst_n(rst_n),
        .rr_interval_ms(rr_interval_ms), .new_rr_pulse(new_rr_pulse),
        .type_code(type_code), .tachy_flag(tachy_flag),
        .normal_flag(normal_flag), .brady_flag(brady_flag),
        .total_beats(total_beats), .tachy_count(tachy_count),
        .normal_count(normal_count), .brady_count(brady_count)
    );

    initial clk = 0;
    always #500 clk = ~clk;

    integer errors;

    task do_reset;
        begin
            rst_n=0; new_rr_pulse=0; rr_interval_ms=0;
            repeat(5) @(posedge clk); rst_n=1; @(posedge clk); #1;
        end
    endtask

    task send_rr;
        input [11:0] rr;
        begin
            @(posedge clk); #1; rr_interval_ms=rr; new_rr_pulse=1;
            @(posedge clk); #1; new_rr_pulse=0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $display("========================================");
        $display("TB3: arrhythmia_compare");
        $display("========================================");
        errors=0; do_reset;

        // 3a: Reset state — normal_flag=1 by design
        if (normal_flag!==1'b1||tachy_flag!==1'b0||brady_flag!==1'b0) begin
            $display("  [FAIL] 3a: wrong reset state (n=%b t=%b b=%b)",
                     normal_flag,tachy_flag,brady_flag); errors=errors+1;
        end else $display("  [PASS] 3a: reset state correct");

        send_rr(12'd400);
        if (!tachy_flag||normal_flag||brady_flag) begin
            $display("  [FAIL] 3b: 400ms should be tachy"); errors=errors+1;
        end else $display("  [PASS] 3b: 400ms = tachy");

        send_rr(12'd599);
        if (!tachy_flag) begin
            $display("  [FAIL] 3c: 599ms should be tachy"); errors=errors+1;
        end else $display("  [PASS] 3c: 599ms = tachy boundary");

        send_rr(12'd600);
        if (!normal_flag||tachy_flag||brady_flag) begin
            $display("  [FAIL] 3d: 600ms should be normal"); errors=errors+1;
        end else $display("  [PASS] 3d: 600ms = normal boundary");

        send_rr(12'd800);
        if (!normal_flag||tachy_flag||brady_flag) begin
            $display("  [FAIL] 3e: 800ms should be normal"); errors=errors+1;
        end else $display("  [PASS] 3e: 800ms = normal");

        send_rr(12'd1000);
        if (!normal_flag) begin
            $display("  [FAIL] 3f: 1000ms should be normal"); errors=errors+1;
        end else $display("  [PASS] 3f: 1000ms = normal boundary");

        send_rr(12'd1001);
        if (!brady_flag||normal_flag||tachy_flag) begin
            $display("  [FAIL] 3g: 1001ms should be brady"); errors=errors+1;
        end else $display("  [PASS] 3g: 1001ms = brady boundary");

        send_rr(12'd1200);
        if (!brady_flag) begin
            $display("  [FAIL] 3h: 1200ms should be brady"); errors=errors+1;
        end else $display("  [PASS] 3h: 1200ms = brady");

        // 3i: Counters — 2 tachy, 3 normal, 1 brady
        do_reset;
        send_rr(12'd400); send_rr(12'd500);
        send_rr(12'd700); send_rr(12'd800); send_rr(12'd900);
        send_rr(12'd1100);
        $display("  [INFO] 3i: total=%0d tachy=%0d normal=%0d brady=%0d",
                 total_beats,tachy_count,normal_count,brady_count);
        if (total_beats!==16'd6||tachy_count!==16'd2||
            normal_count!==16'd3||brady_count!==16'd1) begin
            $display("  [FAIL] 3i: counters wrong"); errors=errors+1;
        end else $display("  [PASS] 3i: counters correct");

        // 3j: Flags hold between pulses
        repeat(5) @(posedge clk);
        if (!brady_flag) begin
            $display("  [FAIL] 3j: flags should hold"); errors=errors+1;
        end else $display("  [PASS] 3j: flags hold between pulses");

        if (errors==0) $display("  [PASS] arrhythmia_compare: all passed");
        else           $display("  [FAIL] arrhythmia_compare: %0d error(s)", errors);
        $display(""); $finish;
    end
endmodule


// ============================================================
// TB4 - irregularity_detector
// Drives rr_interval_ms directly — no debounce involved
// ============================================================
module tb_irregularity_detector;
    reg        clk, rst_n;
    reg [11:0] rr_interval_ms;
    reg        new_rr_pulse;
    wire       irreg_flag;
    wire [15:0] irreg_count;

    irregularity_detector #(.IRREG_THRESH_MS(12'd200)) dut (
        .clk_div(clk), .rst_n(rst_n),
        .rr_interval_ms(rr_interval_ms), .new_rr_pulse(new_rr_pulse),
        .irreg_flag(irreg_flag), .irreg_count(irreg_count)
    );

    initial clk = 0;
    always #500 clk = ~clk;

    integer errors;

    task do_reset;
        begin
            rst_n=0; new_rr_pulse=0; rr_interval_ms=0;
            repeat(5) @(posedge clk); rst_n=1; @(posedge clk); #1;
        end
    endtask

    task send_rr;
        input [11:0] rr;
        begin
            @(posedge clk); #1; rr_interval_ms=rr; new_rr_pulse=1;
            @(posedge clk); #1; new_rr_pulse=0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $display("========================================");
        $display("TB4: irregularity_detector");
        $display("========================================");
        errors=0; do_reset;

        send_rr(12'd800);
        if (irreg_flag!==1'b0) begin
            $display("  [FAIL] 4a: flag after first beat"); errors=errors+1;
        end else $display("  [PASS] 4a: no flag after first beat");

        send_rr(12'd800);
        if (irreg_flag!==1'b0) begin
            $display("  [FAIL] 4b: flag for identical intervals"); errors=errors+1;
        end else $display("  [PASS] 4b: no flag for identical intervals");

        send_rr(12'd900); // diff=100 < 200 threshold
        if (irreg_flag!==1'b0) begin
            $display("  [FAIL] 4c: 100ms should not flag"); errors=errors+1;
        end else $display("  [PASS] 4c: 100ms variation ignored");

        send_rr(12'd700); // diff=200, not > 200 so should NOT flag
        if (irreg_flag!==1'b0) begin
            $display("  [FAIL] 4d: exactly 200ms should not flag"); errors=errors+1;
        end else $display("  [PASS] 4d: exactly threshold not flagged");

        send_rr(12'd1101); // diff=401 > 200 → should flag
        @(posedge clk); #1;
        if (irreg_flag!==1'b1) begin
            $display("  [FAIL] 4e: 401ms should flag"); errors=errors+1;
        end else $display("  [PASS] 4e: large variation flagged");

        @(posedge clk); #1;
        if (irreg_flag!==1'b0) begin
            $display("  [FAIL] 4f: flag should clear"); errors=errors+1;
        end else $display("  [PASS] 4f: flag is 1 cycle wide");

        // 4g: Count accumulates
        do_reset;
        send_rr(12'd800); send_rr(12'd800); send_rr(12'd800);
        send_rr(12'd1200); @(posedge clk); #1; // diff=400 → count=1
        send_rr(12'd800);  @(posedge clk); #1; // diff=400 → count=2
        send_rr(12'd800);                       // diff=0 → no flag
        $display("  [INFO] 4g: irreg_count=%0d (expect 2)", irreg_count);
        if (irreg_count!==16'd2) begin
            $display("  [FAIL] 4g: count wrong"); errors=errors+1;
        end else $display("  [PASS] 4g: count correct");

        do_reset; #1;
        if (irreg_count!==16'd0||irreg_flag!==1'b0) begin
            $display("  [FAIL] 4h: reset did not clear"); errors=errors+1;
        end else $display("  [PASS] 4h: reset clears state");

        if (errors==0) $display("  [PASS] irregularity_detector: all passed");
        else           $display("  [FAIL] irregularity_detector: %0d error(s)", errors);
        $display(""); $finish;
    end
endmodule


// ============================================================
// TB5 - final_analyzer
// FIXED: now uses rst_n (active-low) matching the design fix
// ============================================================
module tb_final_analyzer;
    reg        clk, rst_n;
    reg        rr_valid;
    reg        live_brady, live_tachy, live_irreg, live_normal;
    reg        force_anlz;
    wire [1:0] final_diag;
    wire       diag_valid;
    wire [7:0] confidence;

    final_analyzer dut (
        .clk(clk), .rst_n(rst_n), .rr_valid(rr_valid),
        .live_brady(live_brady), .live_tachy(live_tachy),
        .live_irreg(live_irreg), .live_normal(live_normal),
        .force_anlz(force_anlz), .final_diag(final_diag),
        .diag_valid(diag_valid), .confidence(confidence)
    );

    initial clk = 0;
    always #500 clk = ~clk;

    integer errors;

    task do_reset;
        begin
            rst_n=0; rr_valid=0; live_brady=0; live_tachy=0;
            live_irreg=0; live_normal=0; force_anlz=0;
            repeat(5) @(posedge clk); rst_n=1; @(posedge clk); #1;
        end
    endtask

    task send_beat;
        input b, t, ir, n;
        begin
            @(posedge clk); #1;
            live_brady=b; live_tachy=t; live_irreg=ir; live_normal=n; rr_valid=1;
            @(posedge clk); #1;
            rr_valid=0; live_brady=0; live_tachy=0; live_irreg=0; live_normal=0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $display("========================================");
        $display("TB5: final_analyzer");
        $display("========================================");
        errors=0; do_reset;

        // 5a: diag_valid=0 after reset
        if (diag_valid!==1'b0) begin
            $display("  [FAIL] 5a: diag_valid should be 0"); errors=errors+1;
        end else $display("  [PASS] 5a: diag_valid=0 after reset");

        // 5b: 8 normal → normal
        do_reset; repeat(8) send_beat(0,0,0,1);
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5b: diag=%02b valid=%b conf=%0d",final_diag,diag_valid,confidence);
        if (diag_valid!==1'b1||final_diag!==2'b00) begin
            $display("  [FAIL] 5b: expected normal (00)"); errors=errors+1;
        end else $display("  [PASS] 5b: 8 normal → normal");

        // 5c: 8 tachy → tachy
        do_reset; repeat(8) send_beat(0,1,0,0);
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5c: diag=%02b valid=%b",final_diag,diag_valid);
        if (diag_valid!==1'b1||final_diag!==2'b10) begin
            $display("  [FAIL] 5c: expected tachy (10)"); errors=errors+1;
        end else $display("  [PASS] 5c: 8 tachy → tachy");

        // 5d: 8 brady → brady
        do_reset; repeat(8) send_beat(1,0,0,0);
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5d: diag=%02b valid=%b",final_diag,diag_valid);
        if (diag_valid!==1'b1||final_diag!==2'b01) begin
            $display("  [FAIL] 5d: expected brady (01)"); errors=errors+1;
        end else $display("  [PASS] 5d: 8 brady → brady");

        // 5e: 8 irreg → irreg
        do_reset; repeat(8) send_beat(0,0,1,0);
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5e: diag=%02b valid=%b",final_diag,diag_valid);
        if (diag_valid!==1'b1||final_diag!==2'b11) begin
            $display("  [FAIL] 5e: expected irreg (11)"); errors=errors+1;
        end else $display("  [PASS] 5e: 8 irreg → irregular");

        // 5f: 5 tachy 3 normal → tachy majority
        do_reset;
        repeat(5) send_beat(0,1,0,0);
        repeat(3) send_beat(0,0,0,1);
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5f: diag=%02b conf=%0d",final_diag,confidence);
        if (final_diag!==2'b10) begin
            $display("  [FAIL] 5f: expected tachy majority"); errors=errors+1;
        end else $display("  [PASS] 5f: tachy majority wins");

        // 5g: confidence=255 for 8/8
        do_reset; repeat(8) send_beat(1,0,0,0);
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5g: confidence=%0d (expect 255)",confidence);
        if (confidence!==8'hFF) begin
            $display("  [FAIL] 5g: confidence should be 255"); errors=errors+1;
        end else $display("  [PASS] 5g: confidence=255 for 8/8");

        // 5h: Auto re-fires every 8 beats
        do_reset;
        repeat(8) send_beat(0,1,0,0); // window 1: tachy
        repeat(3) @(posedge clk); #1;
        if (diag_valid!==1'b1||final_diag!==2'b10) begin
            $display("  [FAIL] 5h: first window wrong"); errors=errors+1;
        end else $display("  [PASS] 5h: first window → tachy");
        repeat(8) send_beat(1,0,0,0); // window 2: brady
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5h: second window diag=%02b (expect 01=brady)",final_diag);
        if (final_diag!==2'b01) begin
            $display("  [FAIL] 5h: second window wrong"); errors=errors+1;
        end else $display("  [PASS] 5h: second window → brady");

        // 5i: Force after 4 beats
        do_reset; repeat(4) send_beat(0,1,0,0);
        @(posedge clk); #1; force_anlz=1;
        repeat(3) @(posedge clk); #1; force_anlz=0;
        repeat(3) @(posedge clk); #1;
        $display("  [INFO] 5i: forced diag=%02b valid=%b",final_diag,diag_valid);
        if (diag_valid!==1'b1) begin
            $display("  [FAIL] 5i: diag_valid not set after force"); errors=errors+1;
        end else $display("  [PASS] 5i: force triggers diagnosis");

        // 5j: Force with <4 beats ignored
        do_reset; repeat(3) send_beat(0,0,0,1);
        @(posedge clk); #1; force_anlz=1;
        repeat(3) @(posedge clk); #1; force_anlz=0;
        repeat(3) @(posedge clk); #1;
        if (diag_valid!==1'b0) begin
            $display("  [FAIL] 5j: force with <4 beats should be ignored"); errors=errors+1;
        end else $display("  [PASS] 5j: force ignored with <4 beats");

        if (errors==0) $display("  [PASS] final_analyzer: all passed");
        else           $display("  [FAIL] final_analyzer: %0d error(s)", errors);
        $display(""); $finish;
    end
endmodule


// ============================================================
// TB6 - Top-level integration using dut_fast (DIV=2)
//
// MS=2: 1 "ms" = 2 master clock cycles (matches DIV=2)
//
// DEBOUNCE: interval_detection requires pulse_in held HIGH
// for DEBOUNCE_MS=10 divided-clock ticks before registering.
// With DIV=2: 10 ticks * 2 master cycles = 20 master cycles.
// send_beat holds pulse HIGH for 25 master cycles to be safe.
//
// wait_ms accounts for debounce: subtracts 25 cycles from
// each inter-beat gap so total spacing stays correct.
// ============================================================
module tb_top_level;
    reg        clk, rst_n, ena;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    wire       tachy_flag = uo_out[0];
    wire       normal_flag= uo_out[1];
    wire       brady_flag = uo_out[2];
    wire       irreg_flag = uo_out[3];
    wire [1:0] final_diag = uo_out[5:4];
    wire       diag_valid = uo_out[6];
    wire [7:0] confidence = uio_out;

    dut_fast dut (
        .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in),
        .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    initial clk = 0;
    always #10 clk = ~clk; // 50 MHz = 20ns period

    integer errors;
    localparam MS = 2; // master cycles per "ms" (DIV=2)

    task do_reset;
        begin
            rst_n=0; ui_in=8'd0;
            repeat(MS*20) @(posedge clk);
            rst_n=1;
            repeat(MS*20) @(posedge clk); // extra settle time
            #1;
        end
    endtask

    // Hold pulse HIGH for 25 master cycles = 12 div-clk ticks
    // This exceeds DEBOUNCE_MS=10 so beat is always registered
    task send_beat;
        begin
            @(posedge clk); #1; ui_in[0]=1;
            repeat(25) @(posedge clk); #1;
            ui_in[0]=0;
            repeat(3) @(posedge clk); // brief low gap
        end
    endtask

    // Wait N "ms" worth of master cycles, minus beat pulse width
    // so that total beat-to-beat spacing = N ms
    task wait_ms;
        input integer ms;
        integer cycles;
        integer i;
        begin
            cycles = ms * MS;
            // subtract the 25+3 = 28 cycles used by send_beat
            if (cycles > 28) cycles = cycles - 28;
            for(i=0;i<cycles;i=i+1) @(posedge clk);
        end
    endtask

    task force_analysis;
        begin
            @(posedge clk); #1; ui_in[1]=1;
            repeat(MS*5) @(posedge clk);
            ui_in[1]=0;
            repeat(MS*10) @(posedge clk);
        end
    endtask

    initial begin
        $display("========================================");
        $display("TB6: Top-level integration");
        $display("========================================");
        errors=0; ena=1; ui_in=8'd0; uio_in=8'd0;
        do_reset;

        // 6a: Reset clears flags
        if (tachy_flag||brady_flag||irreg_flag||diag_valid) begin
            $display("  [FAIL] 6a: unexpected flags after reset (uo_out=%08b)",uo_out);
            errors=errors+1;
        end else $display("  [PASS] 6a: flags cleared after reset");

        // 6b: uio_oe=0xFF
        if (uio_oe!==8'hFF) begin
            $display("  [FAIL] 6b: uio_oe=%02h",uio_oe); errors=errors+1;
        end else $display("  [PASS] 6b: uio_oe=0xFF");

        // 6c: Normal sinus 800ms — 9 beats fills the 8-beat window
        $display("  [INFO] 6c: 9 beats at 800ms (normal sinus)...");
        repeat(9) begin send_beat; wait_ms(800); end
        repeat(MS*10) @(posedge clk); #1;
        $display("  [INFO] 6c: normal=%b tachy=%b brady=%b irreg=%b",
                 normal_flag,tachy_flag,brady_flag,irreg_flag);
        if (!normal_flag||tachy_flag||brady_flag) begin
            $display("  [FAIL] 6c: expected normal rhythm"); errors=errors+1;
        end else $display("  [PASS] 6c: normal sinus detected");

        // 6d: Final diagnosis should be set after 8 beats
        $display("  [INFO] 6d: diag_valid=%b final_diag=%02b confidence=%0d",
                 diag_valid,final_diag,confidence);
        if (!diag_valid) begin
            $display("  [FAIL] 6d: diag_valid not set after 8 beats"); errors=errors+1;
        end else if (final_diag!==2'b00) begin
            $display("  [FAIL] 6d: expected normal (00) got %02b",final_diag); errors=errors+1;
        end else $display("  [PASS] 6d: final diagnosis = normal");

        // 6e: Tachycardia 400ms
        do_reset;
        $display("  [INFO] 6e: 9 beats at 400ms (tachycardia)...");
        repeat(9) begin send_beat; wait_ms(400); end
        repeat(MS*10) @(posedge clk); #1;
        $display("  [INFO] 6e: tachy=%b normal=%b brady=%b",tachy_flag,normal_flag,brady_flag);
        if (!tachy_flag) begin
            $display("  [FAIL] 6e: tachycardia not detected"); errors=errors+1;
        end else $display("  [PASS] 6e: tachycardia detected");

        // 6f: Bradycardia 1200ms
        do_reset;
        $display("  [INFO] 6f: 9 beats at 1200ms (bradycardia)...");
        repeat(9) begin send_beat; wait_ms(1200); end
        repeat(MS*10) @(posedge clk); #1;
        $display("  [INFO] 6f: brady=%b normal=%b tachy=%b",brady_flag,normal_flag,tachy_flag);
        if (!brady_flag) begin
            $display("  [FAIL] 6f: bradycardia not detected"); errors=errors+1;
        end else $display("  [PASS] 6f: bradycardia detected");

        // 6g: Irregular rhythm — alternating 800ms/1200ms
        // diff = 400ms > IRREG_THRESH_MS=200 → should flag
        do_reset;
        $display("  [INFO] 6g: alternating 800ms/1200ms (irregular)...");
        repeat(6) begin
            send_beat; wait_ms(800);
            send_beat; wait_ms(1200);
        end
        repeat(MS*10) @(posedge clk); #1;
        $display("  [INFO] 6g: irreg=%b",irreg_flag);
        if (!irreg_flag) begin
            $display("  [FAIL] 6g: irregular rhythm not detected"); errors=errors+1;
        end else $display("  [PASS] 6g: irregular rhythm detected");

        // 6h: Force analysis after 4 brady beats
        do_reset;
        $display("  [INFO] 6h: force analysis after 4 brady beats...");
        repeat(4) begin send_beat; wait_ms(1200); end
        force_analysis;
        $display("  [INFO] 6h: diag_valid=%b final_diag=%02b (expect 01=brady)",
                 diag_valid,final_diag);
        if (!diag_valid) begin
            $display("  [FAIL] 6h: diag_valid not set"); errors=errors+1;
        end else if (final_diag!==2'b01) begin
            $display("  [FAIL] 6h: expected brady (01) got %02b",final_diag); errors=errors+1;
        end else $display("  [PASS] 6h: forced analysis → brady");

        // 6i: Auto-diagnosis fires every 8 beats
        do_reset;
        $display("  [INFO] 6i: auto-diagnosis every 8 beats...");
        repeat(9) begin send_beat; wait_ms(400); end
        repeat(MS*10) @(posedge clk); #1;
        if (!diag_valid||final_diag!==2'b10) begin
            $display("  [FAIL] 6i: expected tachy auto-diagnosis"); errors=errors+1;
        end else $display("  [PASS] 6i: auto-diagnosis fires at 8 beats");

        // 6j: Reset clears everything
        do_reset;
        if (tachy_flag||brady_flag||irreg_flag||diag_valid) begin
            $display("  [FAIL] 6j: flags not cleared"); errors=errors+1;
        end else $display("  [PASS] 6j: reset clears all flags");

        $display("");
        $display("========================================");
        if (errors==0) $display("ALL TESTS PASSED");
        else           $display("TOTAL FAILURES: %0d", errors);
        $display("========================================");
        $finish;
    end
endmodule
