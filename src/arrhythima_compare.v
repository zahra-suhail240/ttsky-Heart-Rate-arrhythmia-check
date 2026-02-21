/ arrhythmia_compare.v
// Uses tick_1ms (1 ms strobe) to measure beat-to-beat interval in milliseconds.
// On each beat_pulse, it classifies and updates counters.
//
// Thresholds (ms):
//  - Tachy:  interval_ms <  600
//  - Normal: 600 <= interval_ms <= 1000
//  - Brady:  interval_ms > 1000

module arrhythmia_compare #(
    parameter integer COUNT_W = 16,  // width for type counters + total beats
    parameter integer MS_W    = 20,  // width for ms interval counter (enough for many seconds)
    parameter integer TACHY_MS_MAX = 600,
    parameter integer BRADY_MS_MIN = 1000
)(
    input  wire clk,
    input  wire rst_n,

    input  wire tick_1ms,     // 1-cycle pulse every 1 ms
    input  wire beat_pulse,   // 1-cycle pulse when heartbeat detected

    // Live outputs (update on each beat, hold until next beat)
    output reg  [1:0] type_code,     // 00=tachy, 01=normal, 10=brady, 11=reserved
    output reg        tachy_flag,
    output reg        normal_flag,
    output reg        brady_flag,

    // Debug: last measured interval in ms
    output reg  [MS_W-1:0] last_interval_ms,

    // Counters
    output reg  [COUNT_W-1:0] total_beats,
    output reg  [COUNT_W-1:0] tachy_count,
    output reg  [COUNT_W-1:0] normal_count,
    output reg  [COUNT_W-1:0] brady_count
);

    // Counts milliseconds since last beat
    reg [MS_W-1:0] ms_counter;

    // 1) Time measurement: count ms between beats
    always @(posedge clk) begin
        if (!rst_n) begin
            ms_counter <= {MS_W{1'b0}};
        end else begin
            if (tick_1ms) begin
                ms_counter <= ms_counter + {{(MS_W-1){1'b0}}, 1'b1};
            end

            if (beat_pulse) begin
                ms_counter <= {MS_W{1'b0}};
            end
        end
    end

    // 2) Classify + update counts on beat
    always @(posedge clk) begin
        if (!rst_n) begin
            type_code <= 2'b01; // default normal
            tachy_flag <= 1'b0;
            normal_flag <= 1'b1;
            brady_flag <= 1'b0;

            last_interval_ms <= {MS_W{1'b0}};

            total_beats  <= {COUNT_W{1'b0}};
            tachy_count  <= {COUNT_W{1'b0}};
            normal_count <= {COUNT_W{1'b0}};
            brady_count  <= {COUNT_W{1'b0}};
        end else begin
            if (beat_pulse) begin
                // Latch the interval ending "now"
                last_interval_ms <= ms_counter;

                // Count total beats
                total_beats <= total_beats + {{(COUNT_W-1){1'b0}}, 1'b1};

                // Classify
                if (ms_counter < TACHY_MS_MAX) begin
                    // Tachy
                    type_code   <= 2'b00;
                    tachy_flag  <= 1'b1;
                    normal_flag <= 1'b0;
                    brady_flag  <= 1'b0;

                    tachy_count <= tachy_count + {{(COUNT_W-1){1'b0}}, 1'b1};

                end else if (ms_counter <= BRADY_MS_MIN) begin
                    // Normal (inclusive boundaries)
                    type_code   <= 2'b01;
                    tachy_flag  <= 1'b0;
                    normal_flag <= 1'b1;
                    brady_flag  <= 1'b0;

                    normal_count <= normal_count + {{(COUNT_W-1){1'b0}}, 1'b1};

                end else begin
                    // Brady
                    type_code   <= 2'b10;
                    tachy_flag  <= 1'b0;
                    normal_flag <= 1'b0;
                    brady_flag  <= 1'b1;

                    brady_count <= brady_count + {{(COUNT_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule