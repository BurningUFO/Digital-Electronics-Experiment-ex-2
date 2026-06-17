// Gameplay core for the slot 2 falling-block game.
//
// This module intentionally contains no VGA drawing or board I/O scanning.  It
// owns the game rules: current/next piece state, collision checks, ghost piece,
// locking, line clearing, compaction, score, level, and game-over state.
//
// Timing note: the ghost calculation, piece locking, and row compaction are
// split across multiple 100 MHz cycles.  That keeps critical paths shorter while
// remaining visually equivalent because all work completes inside video-frame
// time.
module slot2_game_core (
    input  wire        clk,
    input  wire        reset,
    input  wire        selected,
    input  wire        frame_tick,
    input  wire        gravity_tick,
    input  wire        move_left,
    input  wire        move_right,
    input  wire        rotate_cw,
    input  wire        soft_drop,
    input  wire        hard_drop,
    output wire [199:0] board,
    output wire [2:0]  piece_type,
    output wire [1:0]  piece_rotation,
    output wire signed [4:0] piece_x,
    output wire [5:0]  piece_y,
    output wire [2:0]  next_type,
    output wire [15:0] score,
    output wire [9:0]  lines,
    output wire [3:0]  level,
    output wire [5:0]  ghost_piece_y,
    output wire        game_over,
    output reg         lock_pulse,
    output reg         line_clear_pulse,
    output reg  [2:0]  line_clear_count
);

    // Main control states.  Work that could be a long combinational path is
    // broken into row/probe states rather than completed in one cycle.
    localparam ST_PLAYING       = 4'd0;
    localparam ST_HARD_DROP     = 4'd1;
    localparam ST_LOCK_ROW      = 4'd2;
    localparam ST_CLEAR_ANIM    = 4'd3;
    localparam ST_ROW_SCAN      = 4'd4;
    localparam ST_COMPACT_PREP  = 4'd5;
    localparam ST_COMPACT_SCAN  = 4'd6;
    localparam ST_COMPACT_APPLY = 4'd7;
    localparam ST_GAME_OVER     = 4'd8;

    reg [3:0] state;
    reg [4:0] clear_delay;

    reg [199:0] board_reg;
    reg [199:0] compact_reg;
    reg [2:0] cur_type;
    reg [1:0] cur_rot;
    reg signed [4:0] cur_x;
    reg [5:0] cur_y;
    reg [5:0] ghost_y_reg;
    reg [2:0] nxt_type;
    reg [15:0] lfsr;
    reg [15:0] score_reg;
    reg [9:0]  total_lines;
    reg [3:0]  level_reg;
    reg        spawn_req;
    reg [19:0] rows_full_reg;
    reg [4:0]  row_scan_idx;
    reg [4:0]  compact_src;
    reg [4:0]  compact_dst;
    reg [2:0]  rows_to_clear;
    reg [1:0]  lock_row_idx;
    reg [5:0]  ghost_probe_y;
    reg        ghost_busy;
    reg        ghost_eval_valid;
    reg        ghost_blocked_q;

    assign board = board_reg;
    assign piece_type = cur_type;
    assign piece_rotation = cur_rot;
    assign piece_x = cur_x;
    assign piece_y = cur_y;
    assign next_type = nxt_type;
    assign score = score_reg;
    assign lines = total_lines;
    assign level = level_reg;
    assign game_over = (state == ST_GAME_OVER);

    // 4x4 tetromino shape ROM.  The 16-bit value is indexed by row*4+column.
    function [15:0] piece_shape;
        input [2:0] ptype;
        input [1:0] prot;
        begin
            case ({ptype, prot})
                {3'd0, 2'd0}: piece_shape = 16'h0F00;
                {3'd0, 2'd1}: piece_shape = 16'h2222;
                {3'd0, 2'd2}: piece_shape = 16'h00F0;
                {3'd0, 2'd3}: piece_shape = 16'h4444;

                {3'd1, 2'd0}: piece_shape = 16'h0660;
                {3'd1, 2'd1}: piece_shape = 16'h0660;
                {3'd1, 2'd2}: piece_shape = 16'h0660;
                {3'd1, 2'd3}: piece_shape = 16'h0660;

                {3'd2, 2'd0}: piece_shape = 16'h00E4;
                {3'd2, 2'd1}: piece_shape = 16'h0464;
                {3'd2, 2'd2}: piece_shape = 16'h04E0;
                {3'd2, 2'd3}: piece_shape = 16'h04C4;

                {3'd3, 2'd0}: piece_shape = 16'h00C6;
                {3'd3, 2'd1}: piece_shape = 16'h0264;
                {3'd3, 2'd2}: piece_shape = 16'h00C6;
                {3'd3, 2'd3}: piece_shape = 16'h0264;

                {3'd4, 2'd0}: piece_shape = 16'h006C;
                {3'd4, 2'd1}: piece_shape = 16'h0462;
                {3'd4, 2'd2}: piece_shape = 16'h006C;
                {3'd4, 2'd3}: piece_shape = 16'h0462;

                {3'd5, 2'd0}: piece_shape = 16'h00E8;
                {3'd5, 2'd1}: piece_shape = 16'h0446;
                {3'd5, 2'd2}: piece_shape = 16'h02E0;
                {3'd5, 2'd3}: piece_shape = 16'h0C44;

                {3'd6, 2'd0}: piece_shape = 16'h00E2;
                {3'd6, 2'd1}: piece_shape = 16'h0644;
                {3'd6, 2'd2}: piece_shape = 16'h08E0;
                {3'd6, 2'd3}: piece_shape = 16'h044C;
                default: piece_shape = 16'h0000;
            endcase
        end
    endfunction

    // Return one 10-bit board row.  Out-of-range rows are treated as full so
    // collision checks naturally block movement below the board.
    function [9:0] board_row;
        input [4:0] row_idx;
        begin
            case (row_idx)
                5'd0:  board_row = board_reg[0 +: 10];
                5'd1:  board_row = board_reg[10 +: 10];
                5'd2:  board_row = board_reg[20 +: 10];
                5'd3:  board_row = board_reg[30 +: 10];
                5'd4:  board_row = board_reg[40 +: 10];
                5'd5:  board_row = board_reg[50 +: 10];
                5'd6:  board_row = board_reg[60 +: 10];
                5'd7:  board_row = board_reg[70 +: 10];
                5'd8:  board_row = board_reg[80 +: 10];
                5'd9:  board_row = board_reg[90 +: 10];
                5'd10: board_row = board_reg[100 +: 10];
                5'd11: board_row = board_reg[110 +: 10];
                5'd12: board_row = board_reg[120 +: 10];
                5'd13: board_row = board_reg[130 +: 10];
                5'd14: board_row = board_reg[140 +: 10];
                5'd15: board_row = board_reg[150 +: 10];
                5'd16: board_row = board_reg[160 +: 10];
                5'd17: board_row = board_reg[170 +: 10];
                5'd18: board_row = board_reg[180 +: 10];
                5'd19: board_row = board_reg[190 +: 10];
                default: board_row = 10'h3ff;
            endcase
        end
    endfunction

    function [3:0] shape_row_bits;
        input [15:0] shape;
        input [1:0] row_idx;
        begin
            case (row_idx)
                2'd0: shape_row_bits = shape[3:0];
                2'd1: shape_row_bits = shape[7:4];
                2'd2: shape_row_bits = shape[11:8];
                default: shape_row_bits = shape[15:12];
            endcase
        end
    endfunction

    // Check one shape row against the board and side/bottom boundaries.
    // Splitting collision this way keeps repeated board-row access localized.
    function row_collision;
        input signed [4:0] px;
        input [6:0] py;
        input [1:0] row_idx;
        input [3:0] row_bits;
        integer col;
        reg [6:0] abs_y;
        reg signed [5:0] abs_x;
        reg [9:0] board_bits;
        reg hit;
        begin
            abs_y = py + {5'd0, row_idx};
            board_bits = 10'd0;
            hit = 1'b0;

            if (row_bits != 4'd0) begin
                if (abs_y[6] || abs_y >= 7'd20) begin
                    hit = 1'b1;
                end else begin
                    board_bits = board_row(abs_y[4:0]);
                    for (col = 0; col < 4; col = col + 1) begin
                        if (row_bits[col]) begin
                            abs_x = px + col;
                            if (abs_x < 0 || abs_x >= 10 || board_bits[abs_x[3:0]]) begin
                                hit = 1'b1;
                            end
                        end
                    end
                end
            end

            row_collision = hit;
        end
    endfunction

    // Full 4-row piece collision helper.
    function collision;
        input signed [4:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        reg [15:0] shape;
        begin
            shape = piece_shape(ptype, prot);
            collision = row_collision(px, py, 2'd0, shape[3:0]) |
                        row_collision(px, py, 2'd1, shape[7:4]) |
                        row_collision(px, py, 2'd2, shape[11:8]) |
                        row_collision(px, py, 2'd3, shape[15:12]);
        end
    endfunction

    // Lock the entire piece into a temporary board value.  The runtime FSM below
    // uses a row-by-row lock path for timing, but this helper documents the full
    // board merge behavior and remains available for reference/reuse.
    function [199:0] lock_to_board;
        input [199:0] old_board;
        input signed [4:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        integer row;
        integer col;
        reg [6:0] abs_y;
        reg signed [5:0] abs_x;
        reg [15:0] shape;
        reg [9:0] row_mask;
        begin
            shape = piece_shape(ptype, prot);
            lock_to_board = old_board;
            for (row = 0; row < 4; row = row + 1) begin
                row_mask = 10'd0;
                abs_y = py + {5'd0, row[1:0]};
                if (!abs_y[6] && abs_y < 7'd20) begin
                    for (col = 0; col < 4; col = col + 1) begin
                        if (shape[row*4 + col]) begin
                            abs_x = px + col;
                            if (!(abs_x < 0 || abs_x >= 10)) begin
                                row_mask[abs_x[3:0]] = 1'b1;
                            end
                        end
                    end

                    case (abs_y[4:0])
                        5'd0:  lock_to_board[0 +: 10]   = old_board[0 +: 10]   | row_mask;
                        5'd1:  lock_to_board[10 +: 10]  = old_board[10 +: 10]  | row_mask;
                        5'd2:  lock_to_board[20 +: 10]  = old_board[20 +: 10]  | row_mask;
                        5'd3:  lock_to_board[30 +: 10]  = old_board[30 +: 10]  | row_mask;
                        5'd4:  lock_to_board[40 +: 10]  = old_board[40 +: 10]  | row_mask;
                        5'd5:  lock_to_board[50 +: 10]  = old_board[50 +: 10]  | row_mask;
                        5'd6:  lock_to_board[60 +: 10]  = old_board[60 +: 10]  | row_mask;
                        5'd7:  lock_to_board[70 +: 10]  = old_board[70 +: 10]  | row_mask;
                        5'd8:  lock_to_board[80 +: 10]  = old_board[80 +: 10]  | row_mask;
                        5'd9:  lock_to_board[90 +: 10]  = old_board[90 +: 10]  | row_mask;
                        5'd10: lock_to_board[100 +: 10] = old_board[100 +: 10] | row_mask;
                        5'd11: lock_to_board[110 +: 10] = old_board[110 +: 10] | row_mask;
                        5'd12: lock_to_board[120 +: 10] = old_board[120 +: 10] | row_mask;
                        5'd13: lock_to_board[130 +: 10] = old_board[130 +: 10] | row_mask;
                        5'd14: lock_to_board[140 +: 10] = old_board[140 +: 10] | row_mask;
                        5'd15: lock_to_board[150 +: 10] = old_board[150 +: 10] | row_mask;
                        5'd16: lock_to_board[160 +: 10] = old_board[160 +: 10] | row_mask;
                        5'd17: lock_to_board[170 +: 10] = old_board[170 +: 10] | row_mask;
                        5'd18: lock_to_board[180 +: 10] = old_board[180 +: 10] | row_mask;
                        5'd19: lock_to_board[190 +: 10] = old_board[190 +: 10] | row_mask;
                        default: ;
                    endcase
                end
            end
        end
    endfunction

    // Build the 10-bit mask for a single locked piece row.  The FSM ORs one row
    // per cycle into board_reg.
    function [9:0] lock_row_mask;
        input signed [4:0] px;
        input [1:0] row_idx;
        input [1:0] prot;
        input [2:0] ptype;
        integer col;
        reg [3:0] row_bits;
        reg signed [5:0] abs_x;
        begin
            row_bits = shape_row_bits(piece_shape(ptype, prot), row_idx);
            lock_row_mask = 10'd0;
            for (col = 0; col < 4; col = col + 1) begin
                if (row_bits[col]) begin
                    abs_x = px + col;
                    if (!(abs_x < 0 || abs_x >= 10)) begin
                        lock_row_mask[abs_x[3:0]] = 1'b1;
                    end
                end
            end
        end
    endfunction

    // Total-line thresholds for level-up.
    function [9:0] level_goal;
        input [3:0] lvl;
        begin
            case (lvl)
                4'd0:  level_goal = 10'd10;
                4'd1:  level_goal = 10'd20;
                4'd2:  level_goal = 10'd30;
                4'd3:  level_goal = 10'd40;
                4'd4:  level_goal = 10'd50;
                4'd5:  level_goal = 10'd60;
                4'd6:  level_goal = 10'd70;
                4'd7:  level_goal = 10'd80;
                4'd8:  level_goal = 10'd90;
                4'd9:  level_goal = 10'd100;
                4'd10: level_goal = 10'd110;
                4'd11: level_goal = 10'd120;
                4'd12: level_goal = 10'd130;
                4'd13: level_goal = 10'd140;
                4'd14: level_goal = 10'd150;
                default: level_goal = 10'd160;
            endcase
        end
    endfunction

    assign ghost_piece_y = ghost_y_reg;

    wire [9:0] next_line_total = total_lines + {7'd0, rows_to_clear};
    wire [9:0] next_level_goal = level_goal(level_reg);
    wire [15:0] level_factor = {12'd0, level_reg} + 16'd1;
    wire current_row_full = &board_row(row_scan_idx);
    wire ghost_probe_blocked = collision(cur_x, {1'b0, ghost_probe_y} + 7'd1, cur_rot, cur_type);
    wire [6:0] lock_abs_y = {1'b0, cur_y} + {5'd0, lock_row_idx};
    wire [9:0] lock_mask = lock_row_mask(cur_x, lock_row_idx, cur_rot, cur_type);

    // Start an iterative ghost-piece search.  The search probes one row at a
    // time across multiple cycles instead of walking the entire drop distance in
    // one combinational path.
    task start_ghost_calc;
        input [5:0] start_y;
        begin
            ghost_probe_y <= start_y;
            ghost_y_reg <= start_y;
            ghost_busy <= 1'b1;
            ghost_eval_valid <= 1'b0;
            ghost_blocked_q <= 1'b0;
        end
    endtask

    // Enter the row-by-row lock sequence and emit the visible lock pulse used by
    // the top-level buzzer/LED logic.
    task begin_lock_piece;
        begin
            lock_row_idx <= 2'd0;
            ghost_busy <= 1'b0;
            ghost_eval_valid <= 1'b0;
            ghost_blocked_q <= 1'b0;
            lock_pulse <= 1'b1;
            state <= ST_LOCK_ROW;
        end
    endtask

    // Main gameplay FSM.
    always @(posedge clk) begin
        if (reset) begin
            state <= ST_PLAYING;
            clear_delay <= 5'd0;
            board_reg <= 200'd0;
            compact_reg <= 200'd0;
            cur_type <= 3'd0;
            cur_rot <= 2'd0;
            cur_x <= 5'sd3;
            cur_y <= 6'd0;
            ghost_y_reg <= 6'd0;
            nxt_type <= 3'd0;
            lfsr <= 16'hACE1;
            score_reg <= 16'd0;
            total_lines <= 10'd0;
            level_reg <= 4'd0;
            spawn_req <= 1'b1;
            rows_full_reg <= 20'd0;
            row_scan_idx <= 5'd0;
            compact_src <= 5'd0;
            compact_dst <= 5'd0;
            rows_to_clear <= 3'd0;
            lock_row_idx <= 2'd0;
            ghost_probe_y <= 6'd0;
            ghost_busy <= 1'b0;
            ghost_eval_valid <= 1'b0;
            ghost_blocked_q <= 1'b0;
            lock_pulse <= 1'b0;
            line_clear_pulse <= 1'b0;
            line_clear_count <= 3'd0;
        end else if (selected) begin
            lock_pulse <= 1'b0;
            line_clear_pulse <= 1'b0;
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            case (state)
                ST_PLAYING: begin
                    // Normal play handles spawning, input movement, gravity,
                    // soft/hard drop requests, and background ghost updates.
                    if (spawn_req) begin
                        spawn_req <= 1'b0;
                        cur_type <= nxt_type;
                        cur_rot <= 2'd0;
                        cur_x <= 5'sd3;
                        cur_y <= 6'd0;
                        start_ghost_calc(6'd0);
                        nxt_type <= (lfsr[2:0] < 3'd7) ? lfsr[2:0] :
                                    (lfsr[5:3] < 3'd7) ? lfsr[5:3] : 3'd0;
                        if (collision(5'sd3, 7'd0, 2'd0, nxt_type)) begin
                            state <= ST_GAME_OVER;
                            ghost_busy <= 1'b0;
                            ghost_eval_valid <= 1'b0;
                        end
                    end else begin
                        if (ghost_busy) begin
                            // Two-cycle ghost probe: first register the
                            // collision result, then either stop or advance.
                            if (!ghost_eval_valid) begin
                                ghost_blocked_q <= ghost_probe_blocked;
                                ghost_eval_valid <= 1'b1;
                            end else if (ghost_blocked_q) begin
                                ghost_y_reg <= ghost_probe_y;
                                ghost_busy <= 1'b0;
                                ghost_eval_valid <= 1'b0;
                            end else begin
                                ghost_probe_y <= ghost_probe_y + 6'd1;
                                ghost_y_reg <= ghost_probe_y + 6'd1;
                                ghost_eval_valid <= 1'b0;
                            end
                        end

                        if (hard_drop) begin
                            state <= ST_HARD_DROP;
                            ghost_busy <= 1'b0;
                            ghost_eval_valid <= 1'b0;
                        end else if (gravity_tick || soft_drop) begin
                            if (!collision(cur_x, {1'b0, cur_y} + 7'd1, cur_rot, cur_type)) begin
                                cur_y <= cur_y + 6'd1;
                                start_ghost_calc(cur_y + 6'd1);
                            end else begin
                                begin_lock_piece();
                            end
                        end else begin
                            if (move_left && !collision(cur_x - 5'sd1, {1'b0, cur_y}, cur_rot, cur_type)) begin
                                cur_x <= cur_x - 5'sd1;
                                start_ghost_calc(cur_y);
                            end else if (move_right && !collision(cur_x + 5'sd1, {1'b0, cur_y}, cur_rot, cur_type)) begin
                                cur_x <= cur_x + 5'sd1;
                                start_ghost_calc(cur_y);
                            end else if (rotate_cw) begin
                                if (!collision(cur_x, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    start_ghost_calc(cur_y);
                                end else if (!collision(cur_x - 5'sd1, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x - 5'sd1;
                                    start_ghost_calc(cur_y);
                                end else if (!collision(cur_x + 5'sd1, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x + 5'sd1;
                                    start_ghost_calc(cur_y);
                                end else if (cur_y > 6'd0 && !collision(cur_x, {1'b0, cur_y} - 7'd1, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_y <= cur_y - 6'd1;
                                    start_ghost_calc(cur_y - 6'd1);
                                end
                            end
                        end
                    end
                end

                ST_HARD_DROP: begin
                    // Hard drop advances one row per clock until the next row
                    // would collide, then locks the piece.
                    if (!collision(cur_x, {1'b0, cur_y} + 7'd1, cur_rot, cur_type)) begin
                        cur_y <= cur_y + 6'd1;
                    end else begin
                        begin_lock_piece();
                    end
                end

                ST_LOCK_ROW: begin
                    // Merge one 4x4 shape row into board_reg per cycle.  This
                    // avoids a wide one-cycle board update.
                    case (lock_abs_y)
                        7'd0:  board_reg[0 +: 10]   <= board_reg[0 +: 10]   | lock_mask;
                        7'd1:  board_reg[10 +: 10]  <= board_reg[10 +: 10]  | lock_mask;
                        7'd2:  board_reg[20 +: 10]  <= board_reg[20 +: 10]  | lock_mask;
                        7'd3:  board_reg[30 +: 10]  <= board_reg[30 +: 10]  | lock_mask;
                        7'd4:  board_reg[40 +: 10]  <= board_reg[40 +: 10]  | lock_mask;
                        7'd5:  board_reg[50 +: 10]  <= board_reg[50 +: 10]  | lock_mask;
                        7'd6:  board_reg[60 +: 10]  <= board_reg[60 +: 10]  | lock_mask;
                        7'd7:  board_reg[70 +: 10]  <= board_reg[70 +: 10]  | lock_mask;
                        7'd8:  board_reg[80 +: 10]  <= board_reg[80 +: 10]  | lock_mask;
                        7'd9:  board_reg[90 +: 10]  <= board_reg[90 +: 10]  | lock_mask;
                        7'd10: board_reg[100 +: 10] <= board_reg[100 +: 10] | lock_mask;
                        7'd11: board_reg[110 +: 10] <= board_reg[110 +: 10] | lock_mask;
                        7'd12: board_reg[120 +: 10] <= board_reg[120 +: 10] | lock_mask;
                        7'd13: board_reg[130 +: 10] <= board_reg[130 +: 10] | lock_mask;
                        7'd14: board_reg[140 +: 10] <= board_reg[140 +: 10] | lock_mask;
                        7'd15: board_reg[150 +: 10] <= board_reg[150 +: 10] | lock_mask;
                        7'd16: board_reg[160 +: 10] <= board_reg[160 +: 10] | lock_mask;
                        7'd17: board_reg[170 +: 10] <= board_reg[170 +: 10] | lock_mask;
                        7'd18: board_reg[180 +: 10] <= board_reg[180 +: 10] | lock_mask;
                        7'd19: board_reg[190 +: 10] <= board_reg[190 +: 10] | lock_mask;
                        default: ;
                    endcase

                    if (lock_row_idx == 2'd3) begin
                        state <= ST_CLEAR_ANIM;
                        clear_delay <= 5'd20;
                    end else begin
                        lock_row_idx <= lock_row_idx + 2'd1;
                    end
                end

                ST_CLEAR_ANIM: begin
                    // Small delay after locking before scanning rows.  It gives
                    // visual/audio feedback without changing game rules.
                    if (clear_delay > 5'd0) begin
                        clear_delay <= clear_delay - 5'd1;
                    end else begin
                        rows_full_reg <= 20'd0;
                        rows_to_clear <= 3'd0;
                        row_scan_idx <= 5'd0;
                        state <= ST_ROW_SCAN;
                    end
                end

                ST_ROW_SCAN: begin
                    // Scan all 20 board rows and record which rows are full.
                    if (current_row_full) begin
                        rows_full_reg[row_scan_idx] <= 1'b1;
                        if (rows_to_clear < 3'd4) rows_to_clear <= rows_to_clear + 3'd1;
                    end

                    if (row_scan_idx == 5'd19) begin
                        state <= ST_COMPACT_PREP;
                    end else begin
                        row_scan_idx <= row_scan_idx + 5'd1;
                    end
                end

                ST_COMPACT_PREP: begin
                    // Prepare a fresh compacted board image.
                    compact_reg <= 200'd0;
                    compact_src <= 5'd19;
                    compact_dst <= 5'd19;
                    state <= ST_COMPACT_SCAN;
                end

                ST_COMPACT_SCAN: begin
                    // Copy non-full rows downward from bottom to top.
                    if (!rows_full_reg[compact_src]) begin
                        compact_reg[compact_dst*10 +: 10] <= board_reg[compact_src*10 +: 10];
                        if (compact_dst > 5'd0) compact_dst <= compact_dst - 5'd1;
                    end

                    if (compact_src == 5'd0) begin
                        state <= ST_COMPACT_APPLY;
                    end else begin
                        compact_src <= compact_src - 5'd1;
                    end
                end

                ST_COMPACT_APPLY: begin
                    // Commit cleared rows, score, line count, and level.  Then
                    // request a fresh piece spawn in ST_PLAYING.
                    if (rows_to_clear > 3'd0) begin
                        board_reg <= compact_reg;
                        line_clear_pulse <= 1'b1;
                        line_clear_count <= rows_to_clear;
                        case (rows_to_clear)
                            3'd1: score_reg <= score_reg + 16'd100 * level_factor;
                            3'd2: score_reg <= score_reg + 16'd300 * level_factor;
                            3'd3: score_reg <= score_reg + 16'd500 * level_factor;
                            3'd4: score_reg <= score_reg + 16'd800 * level_factor;
                            default: ;
                        endcase
                        total_lines <= total_lines + {7'd0, rows_to_clear};
                        if (next_line_total >= next_level_goal && level_reg < 4'd15)
                            level_reg <= level_reg + 4'd1;
                    end
                    ghost_y_reg <= 6'd0;
                    state <= ST_PLAYING;
                    spawn_req <= 1'b1;
                    rows_to_clear <= 3'd0;
                end

                ST_GAME_OVER: begin
                    // Wait for hard_drop as a simple restart command.
                end
            endcase
        end
    end

endmodule

