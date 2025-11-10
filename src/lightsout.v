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

    // ---- Assign to Tiny Tapeout I/O pins ----
    assign uo_out[0] = LED_ROW0;
    assign uo_out[1] = LED_ROW1;
    assign uo_out[2] = LED_ROW2;

    assign uo_out[3] = COL0;
    assign uo_out[4] = COL1;
    assign uo_out[5] = COL2;

    // Any unused outputs set to 0
    assign uo_out[7:6] = 2'b00;

    // All bidirectional IOs unused here
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // --- Actual module logic starts here ---

    // --- LED matrix state (row-major) ---
    reg [8:0] leds;

    // --- Multiplexing counter ---
    reg [3:0] mux_state;
    always @(posedge CLK) begin
        if (!RESET_N)
            mux_state <= 4'd0;
        else if (mux_state == 4'd8)
            mux_state <= 4'd0;
        else
            mux_state <= mux_state + 1'b1;
    end

    // Decode current row/col
    wire [1:0] row = mux_state / 3;
    wire [1:0] col = mux_state % 3;

    // --- LED drive ---
    always @(*) begin
        {COL2, COL1, COL0} = 3'b000;
        {LED_ROW2, LED_ROW1, LED_ROW0} = 3'b111;

        // Activate current column
        case (col)
            2'd0: COL0 = 1'b1;
            2'd1: COL1 = 1'b1;
            2'd2: COL2 = 1'b1;
        endcase

        // Drive LED if bit set
        if (leds[mux_state]) begin
            case (row)
                2'd0: LED_ROW0 = 1'b0;
                2'd1: LED_ROW1 = 1'b0;
                2'd2: LED_ROW2 = 1'b0;
            endcase
        end
    end

    // --- Button debouncing ---
    // Shift registers for each button
    reg [15:0] btn_shift [0:8]; // 16-bit shift register per button
    reg [8:0]  btn_debounced;   // debounced positive-edge flag

    integer i;

    always @(posedge CLK) begin
        if (!RESET_N) begin
            for (i=0; i<9; i=i+1) begin
                btn_shift[i] <= 16'd0;
                btn_debounced[i] <= 1'b0;
            end
        end else begin
          // Sample buttons based on current column
          // Column = 0 - BTN_ROW0/1/2 mapped to idx 0,3,6
          // Column = 1 - idx 1,4,7
          // Column = 2 - idx 2,5,8
          case (col)
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
  localparam [8:0] TOGGLE_MASK2 = 9'b000100101;
  localparam [8:0] TOGGLE_MASK3 = 9'b000111001;
  localparam [8:0] TOGGLE_MASK4 = 9'b010111010;
  localparam [8:0] TOGGLE_MASK5 = 9'b100110100;
  localparam [8:0] TOGGLE_MASK6 = 9'b011001000;
  localparam [8:0] TOGGLE_MASK7 = 9'b111010000;
  localparam [8:0] TOGGLE_MASK8 = 9'b110100000;

  reg [8:0] leds_next;

  // Implement the lights-out game logic
  always @(posedge CLK) begin
      // LFSR clocks in background, intentionally don't initialize
      // x^16 + x^14 + x^13 + x^11
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

      // Determine next LED state
      leds_next = leds;

      // Load random state if any button pressed when LEDs are off or on RESET
      if (!RESET_N || ((|btn_debounced) && leds == 0)) begin
          leds_next = lfsr[8:0];  // load 9 LSBs of LFSR
      end else begin
        // Toggle LED's based on button presses
        for (i=0; i<9; i=i+1) begin
            if (btn_debounced[i]) begin
              case (i)
                0: leds_next = leds_next ^ TOGGLE_MASK0;
                1: leds_next = leds_next ^ TOGGLE_MASK1;
                2: leds_next = leds_next ^ TOGGLE_MASK2;
                3: leds_next = leds_next ^ TOGGLE_MASK3;
                4: leds_next = leds_next ^ TOGGLE_MASK4;
                5: leds_next = leds_next ^ TOGGLE_MASK5;
                6: leds_next = leds_next ^ TOGGLE_MASK6;
                7: leds_next = leds_next ^ TOGGLE_MASK7;
                8: leds_next = leds_next ^ TOGGLE_MASK8;
              endcase
            end
        end
      end

      leds <= leds_next;
  end

endmodule
