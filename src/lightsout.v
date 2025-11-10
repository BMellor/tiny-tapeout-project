/*
 * Copyright (c) 2025 Brent Mellor
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_bmellor_lightsout (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // ---- Alias signals for readability ----
    wire CLK      = clk;
    wire RESET_N  = rst_n;

    // Example pin mapping:
    // Inputs (buttons)
    wire BTN_ROW0 = ui_in[0];
    wire BTN_ROW1 = ui_in[1];
    wire BTN_ROW2 = ui_in[2];

    // Outputs (LED rows)
    wire LED_ROW0;
    wire LED_ROW1;
    wire LED_ROW2;

    // Columns
    wire COL0;
    wire COL1;
    wire COL2;

    // Win/restart LED
    wire DONE;

    // ---- Assign to Tiny Tapeout I/O pins ----
    assign uo_out[0] = LED_ROW0;
    assign uo_out[1] = LED_ROW1;
    assign uo_out[2] = LED_ROW2;

    assign uo_out[3] = COL0;
    assign uo_out[4] = COL1;
    assign uo_out[5] = COL2;

    assign uo_out[6] = DONE;

    // Set unused output to 0
    assign uo_out[7] = 1'b0;

    // All bidirectional IOs unused here
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // --- Actual module logic starts here ---

   // --- LED matrix state (row-major) ---
    reg [8:0] leds;

    // --- Multiplexing counter ---
    reg [1:0] active_col;
    always @(posedge CLK) begin
        if (!RESET_N)
            active_col <= 2'd0;
        else if (active_col == 2'd2)
            active_col <= 2'd0;
        else
            active_col <= active_col + 1'b1;
    end

    // --- LED drive ---
    assign COL0 = (active_col == 2'd0);
    assign COL1 = (active_col == 2'd1);
    assign COL2 = (active_col == 2'd2);
    assign LED_ROW0 = !((active_col == 0) ? leds[0] :
                      (active_col == 1) ? leds[1] : leds[2]);
    assign LED_ROW1 = !((active_col == 0) ? leds[3] :
                      (active_col == 1) ? leds[4] : leds[5]);
    assign LED_ROW2 = !((active_col == 0) ? leds[6] :
                      (active_col == 1) ? leds[7] : leds[8]);

    assign DONE = !(|leds);

    // --- Button debouncing ---
    // Shift registers for each button
    reg [15:0] btn_shift [0:8]; // 16-bit shift register per button
    reg [8:0]  btn_debounced;   // debounced positive-edge flag

    integer i;

    // Sample buttons on opposite edge of clock to ensure lines are stable
    always @(negedge CLK) begin
        if (!RESET_N) begin
            for (i=0; i<9; i=i+1) begin
                btn_shift[i] <= 16'd0;
                btn_debounced[i] <= 1'b0;
            end
        end else begin
            for (i=0; i<9; i=i+1) begin
                btn_debounced[i] <= 1'b0;
            end
          // Sample buttons based on current column
          // Column = 0 - BTN_ROW0/1/2 mapped to idx 0,3,6
          // Column = 1 - idx 1,4,7
          // Column = 2 - idx 2,5,8
          case (active_col)
              2'd0: begin
                  btn_shift[0] <= {btn_shift[0][14:0], BTN_ROW0};
                  btn_shift[3] <= {btn_shift[3][14:0], BTN_ROW1};
                  btn_shift[6] <= {btn_shift[6][14:0], BTN_ROW2};

                  btn_debounced[0] <= (btn_shift[0][15:0] == 16'h7FFF);
                  btn_debounced[3] <= (btn_shift[3][15:0] == 16'h7FFF);
                  btn_debounced[6] <= (btn_shift[6][15:0] == 16'h7FFF);
              end
              2'd1: begin
                  btn_shift[1] <= {btn_shift[1][14:0], BTN_ROW0};
                  btn_shift[4] <= {btn_shift[4][14:0], BTN_ROW1};
                  btn_shift[7] <= {btn_shift[7][14:0], BTN_ROW2};

                  btn_debounced[1] <= (btn_shift[1][15:0] == 16'h7FFF);
                  btn_debounced[4] <= (btn_shift[4][15:0] == 16'h7FFF);
                  btn_debounced[7] <= (btn_shift[7][15:0] == 16'h7FFF);
              end
              2'd2: begin
                  btn_shift[2] <= {btn_shift[2][14:0], BTN_ROW0};
                  btn_shift[5] <= {btn_shift[5][14:0], BTN_ROW1};
                  btn_shift[8] <= {btn_shift[8][14:0], BTN_ROW2};

                  btn_debounced[2] <= (btn_shift[2][15:0] == 16'h7FFF);
                  btn_debounced[5] <= (btn_shift[5][15:0] == 16'h7FFF);
                  btn_debounced[8] <= (btn_shift[8][15:0] == 16'h7FFF);
              end
          endcase
        end
    end


  // 16-bit LFSR to randomize reset and new-game state
  reg [15:0] lfsr;

  localparam [8:0] TOGGLE_MASK0 = 9'b000001011;
  localparam [8:0] TOGGLE_MASK1 = 9'b000010111;
  localparam [8:0] TOGGLE_MASK2 = 9'b000100110;
  localparam [8:0] TOGGLE_MASK3 = 9'b001011001;
  localparam [8:0] TOGGLE_MASK4 = 9'b010111010;
  localparam [8:0] TOGGLE_MASK5 = 9'b100110100;
  localparam [8:0] TOGGLE_MASK6 = 9'b011001000;
  localparam [8:0] TOGGLE_MASK7 = 9'b111010000;
  localparam [8:0] TOGGLE_MASK8 = 9'b110100000;

  reg [8:0] leds_next;

// Implement the lights-out game logic
always @(posedge CLK) begin
    if (!RESET_N) begin
        leds <= 9'b000000000;
        lfsr <= 16'hBEEF;
    end else begin
        // LFSR clocks in background: x^16 + x^14 + x^13 + x^11
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

        if ((|btn_debounced) && leds == 0) begin
            leds <= lfsr[8:0];  // load 9 LSBs of LFSR
        end else begin
            leds <= leds
                    ^ (btn_debounced[0] ? TOGGLE_MASK0 : 9'b0)
                    ^ (btn_debounced[1] ? TOGGLE_MASK1 : 9'b0)
                    ^ (btn_debounced[2] ? TOGGLE_MASK2 : 9'b0)
                    ^ (btn_debounced[3] ? TOGGLE_MASK3 : 9'b0)
                    ^ (btn_debounced[4] ? TOGGLE_MASK4 : 9'b0)
                    ^ (btn_debounced[5] ? TOGGLE_MASK5 : 9'b0)
                    ^ (btn_debounced[6] ? TOGGLE_MASK6 : 9'b0)
                    ^ (btn_debounced[7] ? TOGGLE_MASK7 : 9'b0)
                    ^ (btn_debounced[8] ? TOGGLE_MASK8 : 9'b0);
        end
    end
end

endmodule
