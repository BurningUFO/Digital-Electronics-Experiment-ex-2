module slot4_game_core (
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
    output wire [3:0]  piece_x,
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

    localparam ST_PLAYING    = 2'd0;
    localparam ST_CLEAR_ANIM = 2'd1;
    localparam ST_GAME_OVER  = 2'd2;

    reg [1:0] state;
    reg [4:0] clear_delay;

    reg [199:0] board_reg;
    reg [2:0] cur_type;
    reg [1:0] cur_rot;
    reg [3:0] cur_x;
    reg [5:0] cur_y;
    reg [2:0] nxt_type;
    reg [15:0] lfsr;
    reg [15:0] score_reg;
    reg [9:0]  total_lines;
    reg [3:0]  level_reg;
    reg        spawn_req;

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

    function collision;
        input [3:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        reg hit;
        reg [3:0] row, col;
        reg [4:0] abs_x;
        reg [6:0] abs_y;
        reg [9:0] board_idx;
        reg [15:0] shape;
        begin
            shape = piece_shape(ptype, prot);
            hit = 1'b0;
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    if (shape[row*4 + col]) begin
                        abs_x = {1'b0, px} + {1'b0, col};
                        abs_y = py + {3'd0, row[1:0]};
                        if (abs_x[4] || abs_x[3:0] >= 4'd10) hit = 1'b1;
                        else if (abs_y[6] || abs_y >= 7'd20) hit = 1'b1;
                        else begin
                            board_idx = abs_y[4:0] * 5'd10 + {5'd0, abs_x[3:0]};
                            if (board_reg[board_idx]) hit = 1'b1;
                        end
                    end
                end
            end
            collision = hit;
        end
    endfunction

    function [4:0] drop_dist;
        input [3:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        integer d;
        begin
            drop_dist = 5'd0;
            for (d = 1; d <= 20; d = d + 1) begin
                if (!collision(px, py + d[6:0], prot, ptype))
                    drop_dist = d[4:0];
            end
        end
    endfunction

    // line clear detection
    wire [19:0] row_full;
    genvar gi;
    generate
        for (gi = 0; gi < 20; gi = gi + 1) begin : gen_row_full
            assign row_full[gi] = &board_reg[gi*10 +: 10];
        end
    endgenerate

    // count full rows (0-4)
    function [2:0] count_full;
        input [19:0] rf;
        integer ci;
        reg [2:0] cnt;
        begin
            cnt = 3'd0;
            for (ci = 0; ci < 20; ci = ci + 1) begin
                if (rf[ci]) cnt = cnt + 3'd1;
            end
            count_full = cnt;
        end
    endfunction

    // build new board with full rows removed
    function [199:0] compact_board;
        input [199:0] old_board;
        input [19:0] rf;
        integer src, dst;
        reg [199:0] new_board;
        begin
            new_board = 200'd0;
            dst = 19;
            for (src = 19; src >= 0; src = src - 1) begin
                if (!rf[src]) begin
                    new_board[dst*10 +: 10] = old_board[src*10 +: 10];
                    dst = dst - 1;
                end
            end
            compact_board = new_board;
        end
    endfunction

    // lock piece into board
    function [199:0] lock_to_board;
        input [199:0] old_board;
        input [3:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        integer row, col;
        reg [4:0] abs_x;
        reg [6:0] abs_y;
        reg [199:0] new_board;
        reg [9:0] idx;
        reg [15:0] shape;
        begin
            shape = piece_shape(ptype, prot);
            new_board = old_board;
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    if (shape[row*4 + col]) begin
                        abs_x = {1'b0, px} + {1'b0, col[1:0]};
                        abs_y = py + {3'd0, row[1:0]};
                        if (!abs_x[4] && abs_x[3:0] < 4'd10 && !abs_y[6] && abs_y < 7'd20) begin
                            idx = abs_y[4:0] * 5'd10 + {5'd0, abs_x[3:0]};
                            new_board[idx] = 1'b1;
                        end
                    end
                end
            end
            lock_to_board = new_board;
        end
    endfunction

    wire [4:0] hard_drop_dist;
    assign hard_drop_dist = drop_dist(cur_x, {1'b0, cur_y}, cur_rot, cur_type);
    assign ghost_piece_y = cur_y + {1'b0, hard_drop_dist};

    always @(posedge clk) begin
        if (reset) begin
            state <= ST_PLAYING;
            clear_delay <= 5'd0;
            board_reg <= 200'd0;
            cur_type <= 3'd0;
            cur_rot <= 2'd0;
            cur_x <= 4'd3;
            cur_y <= 6'd0;
            nxt_type <= 3'd0;
            lfsr <= 16'hACE1;
            score_reg <= 16'd0;
            total_lines <= 10'd0;
            level_reg <= 4'd0;
            spawn_req <= 1'b1;
            lock_pulse <= 1'b0;
            line_clear_pulse <= 1'b0;
            line_clear_count <= 3'd0;
        end else if (selected) begin
            lock_pulse <= 1'b0;
            line_clear_pulse <= 1'b0;
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            case (state)
                ST_PLAYING: begin
                    if (spawn_req) begin
                        spawn_req <= 1'b0;
                        cur_type <= nxt_type;
                        cur_rot <= 2'd0;
                        cur_x <= 4'd3;
                        cur_y <= 6'd0;
                        nxt_type <= (lfsr[2:0] < 3'd7) ? lfsr[2:0] :
                                    (lfsr[5:3] < 3'd7) ? lfsr[5:3] : 3'd0;
                        if (collision(4'd3, 7'd0, 2'd0, nxt_type)) begin
                            state <= ST_GAME_OVER;
                        end
                    end else begin
                        if (hard_drop) begin
                            cur_y <= cur_y + {1'b0, hard_drop_dist};
                            board_reg <= lock_to_board(board_reg, cur_x, {1'b0, cur_y} + {2'd0, hard_drop_dist}, cur_rot, cur_type);
                            lock_pulse <= 1'b1;
                            state <= ST_CLEAR_ANIM;
                            clear_delay <= 5'd20;
                        end else if (gravity_tick || soft_drop) begin
                            if (!collision(cur_x, {1'b0, cur_y} + 7'd1, cur_rot, cur_type)) begin
                                cur_y <= cur_y + 6'd1;
                            end else begin
                                board_reg <= lock_to_board(board_reg, cur_x, {1'b0, cur_y}, cur_rot, cur_type);
                                lock_pulse <= 1'b1;
                                state <= ST_CLEAR_ANIM;
                                clear_delay <= 5'd20;
                            end
                        end else begin
                            if (move_left && !collision(cur_x - 4'd1, {1'b0, cur_y}, cur_rot, cur_type))
                                cur_x <= cur_x - 4'd1;
                            if (move_right && !collision(cur_x + 4'd1, {1'b0, cur_y}, cur_rot, cur_type))
                                cur_x <= cur_x + 4'd1;

                            if (rotate_cw) begin
                                if (!collision(cur_x, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                end else if (!collision(cur_x - 4'd1, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x - 4'd1;
                                end else if (!collision(cur_x + 4'd1, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x + 4'd1;
                                end else if (cur_y > 6'd0 && !collision(cur_x, {1'b0, cur_y} - 7'd1, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_y <= cur_y - 6'd1;
                                end
                            end
                        end
                    end
                end

                ST_CLEAR_ANIM: begin
                    if (clear_delay > 5'd0) begin
                        clear_delay <= clear_delay - 5'd1;
                    end else begin
                        if (count_full(row_full) > 3'd0) begin
                            board_reg <= compact_board(board_reg, row_full);
                            line_clear_pulse <= 1'b1;
                            line_clear_count <= count_full(row_full);
                            case (count_full(row_full))
                                3'd1: score_reg <= score_reg + 16'd100 * ({12'd0, level_reg} + 16'd1);
                                3'd2: score_reg <= score_reg + 16'd300 * ({12'd0, level_reg} + 16'd1);
                                3'd3: score_reg <= score_reg + 16'd500 * ({12'd0, level_reg} + 16'd1);
                                3'd4: score_reg <= score_reg + 16'd800 * ({12'd0, level_reg} + 16'd1);
                                default: ;
                            endcase
                            total_lines <= total_lines + {7'd0, count_full(row_full)};
                            if (total_lines + {7'd0, count_full(row_full)} >= ({6'd0, level_reg} + 10'd1) * 10'd10)
                                level_reg <= level_reg + 4'd1;
                        end
                        state <= ST_PLAYING;
                        spawn_req <= 1'b1;
                    end
                end

                ST_GAME_OVER: begin
                end
            endcase
        end
    end

endmodule
