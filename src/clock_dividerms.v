

// clock_divider_tick_ms.v
// Converts 50 MHz clock into:
//   tick_1ms : 1-cycle pulse every 1 ms
//   clk_1khz : 1 kHz square wave

module clock_divider_tick_ms (

    input wire clk,      // 50 MHz clock
    input wire rst_n,    // active-low reset

    output reg tick_1ms, // pulse every 1 ms
    output reg clk_1khz  // square wave at 1 kHz

);

    // 16-bit counter is enough for counting to 49,999
    reg [15:0] cnt;

    always @(posedge clk) begin

        if (!rst_n) begin
            cnt      <= 16'd0;
            tick_1ms <= 1'b0;
            clk_1khz <= 1'b0;
        end

        else begin

            tick_1ms <= 1'b0;  // default: no pulse

            if (cnt == 16'd49999) begin

                cnt <= 16'd0;

                tick_1ms <= 1'b1;    // 1-cycle pulse

                clk_1khz <= ~clk_1khz;  // toggle square wave

            end

            else begin

                cnt <= cnt + 16'd1;

            end

        end

    end

endmodule