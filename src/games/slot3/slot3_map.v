module slot3_map (
    input  wire        clk,
    input  wire        reset,
    input  wire        gen_start,
    input  wire [31:0] seed,
    input  wire [3:0]  level,
    output reg         gen_done,
    input  wire        destroy_en,
    input  wire [4:0]  destroy_tx,
    input  wire [3:0]  destroy_ty,
    input  wire [9:0]  query_x0,
    input  wire [8:0]  query_y0,
    input  wire [9:0]  query_x1,
    input  wire [8:0]  query_y1,
    input  wire [9:0]  query_x2,
    input  wire [8:0]  query_y2,
    input  wire [9:0]  query_x3,
    input  wire [8:0]  query_y3,
    output wire        walk0,
    output wire        walk1,
    output wire        walk2,
    output wire        walk3,
    input  wire [4:0]  render_tx,
    input  wire [3:0]  render_ty,
    output wire [2:0]  render_tile,
    output reg  [3:0]  river_y
);

    localparam [2:0] TILE_STREET   = 3'd0;
    localparam [2:0] TILE_RIVER    = 3'd1;
    localparam [2:0] TILE_BRIDGE   = 3'd2;
    localparam [2:0] TILE_BUILDING = 3'd3;
    localparam [2:0] TILE_TREE     = 3'd4;

    localparam COLS = 20;
    localparam ROWS = 15;

    (* ram_style = "distributed" *) reg [2:0] tile_map [0:299];
    reg        map_we;
    reg [8:0]  map_waddr;
    reg [2:0]  map_wdata;

    function [8:0] tile_addr;
        input [4:0] tx;
        input [3:0] ty;
        begin
            tile_addr = {ty, 4'b0000} + {1'b0, ty, 2'b00} + {4'b0000, tx};
        end
    endfunction

    wire [2:0] t0 = tile_map[tile_addr(query_x0[9:5], query_y0[8:5])];
    wire [2:0] t1 = tile_map[tile_addr(query_x1[9:5], query_y1[8:5])];
    wire [2:0] t2 = tile_map[tile_addr(query_x2[9:5], query_y2[8:5])];
    wire [2:0] t3 = tile_map[tile_addr(query_x3[9:5], query_y3[8:5])];

    wire walkable_tile0 = (t0 == TILE_STREET) || (t0 == TILE_BRIDGE) || (t0 == TILE_TREE);
    wire walkable_tile1 = (t1 == TILE_STREET) || (t1 == TILE_BRIDGE) || (t1 == TILE_TREE);
    wire walkable_tile2 = (t2 == TILE_STREET) || (t2 == TILE_BRIDGE) || (t2 == TILE_TREE);
    wire walkable_tile3 = (t3 == TILE_STREET) || (t3 == TILE_BRIDGE) || (t3 == TILE_TREE);

    wire in_bounds0 = (query_x0 < 10'd640) && (query_y0 < 9'd480);
    wire in_bounds1 = (query_x1 < 10'd640) && (query_y1 < 9'd480);
    wire in_bounds2 = (query_x2 < 10'd640) && (query_y2 < 9'd480);
    wire in_bounds3 = (query_x3 < 10'd640) && (query_y3 < 9'd480);

    assign walk0 = in_bounds0 && walkable_tile0;
    assign walk1 = in_bounds1 && walkable_tile1;
    assign walk2 = in_bounds2 && walkable_tile2;
    assign walk3 = in_bounds3 && walkable_tile3;

    assign render_tile = tile_map[tile_addr(render_tx, render_ty)];

    localparam [2:0] GEN_IDLE   = 3'd0;
    localparam [2:0] GEN_CLEAR  = 3'd1;
    localparam [2:0] GEN_RIVER  = 3'd2;
    localparam [2:0] GEN_BUILD  = 3'd3;
    localparam [2:0] GEN_TREE   = 3'd4;
    localparam [2:0] GEN_SPAWN  = 3'd5;
    localparam [2:0] GEN_DONE   = 3'd6;

    reg [2:0]  gen_state;
    reg [8:0]  gen_idx;
    reg [31:0] gen_lfsr;
    reg [5:0]  gen_count;
    reg [4:0]  gen_bx, gen_by;
    reg [2:0]  gen_bw, gen_bh;
    reg [2:0]  gen_bi, gen_bj;

    wire [4:0] bridge_cols [0:5];
    assign bridge_cols[0] = 5'd5;
    assign bridge_cols[1] = 5'd6;
    assign bridge_cols[2] = 5'd7;
    assign bridge_cols[3] = 5'd13;
    assign bridge_cols[4] = 5'd14;
    assign bridge_cols[5] = 5'd15;

    task lfsr_advance;
        begin
            gen_lfsr <= {gen_lfsr[30:0], gen_lfsr[31] ^ gen_lfsr[29] ^ gen_lfsr[25] ^ gen_lfsr[24]};
        end
    endtask

    always @(posedge clk) begin
        if (!reset && map_we) begin
            tile_map[map_waddr] <= map_wdata;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            gen_state <= GEN_IDLE;
            gen_done <= 1'b0;
            gen_idx <= 9'd0;
            gen_count <= 6'd0;
            river_y <= 4'd6;
            map_we <= 1'b0;
            map_waddr <= 9'd0;
            map_wdata <= TILE_STREET;
        end else begin
            map_we <= 1'b0;

            if (destroy_en) begin
                map_we <= 1'b1;
                map_waddr <= tile_addr(destroy_tx, destroy_ty);
                map_wdata <= TILE_STREET;
            end

            case (gen_state)
                GEN_IDLE: begin
                    if (gen_start) begin
                        gen_state <= GEN_CLEAR;
                        gen_idx <= 9'd0;
                        gen_lfsr <= seed;
                        gen_done <= 1'b0;
                    end
                end

                GEN_CLEAR: begin
                    map_we <= 1'b1;
                    map_waddr <= gen_idx;
                    map_wdata <= TILE_STREET;
                    if (gen_idx == 9'd299) begin
                        gen_state <= GEN_RIVER;
                        gen_idx <= 9'd0;
                        river_y <= 4'd4 + gen_lfsr[2:0];
                        lfsr_advance;
                    end else begin
                        gen_idx <= gen_idx + 9'd1;
                    end
                end

                GEN_RIVER: begin
                    if (gen_idx < 9'd60) begin
                        // 3 rows of river, with bridges at fixed columns
                        begin : river_block
                            reg [4:0] rx;
                            reg [3:0] ry;
                            reg is_bridge;
                            rx = gen_idx[4:0] % 5'd20;
                            ry = river_y + gen_idx[4:0] / 5'd20;
                            is_bridge = (rx == bridge_cols[0]) || (rx == bridge_cols[1]) ||
                                        (rx == bridge_cols[2]) || (rx == bridge_cols[3]) ||
                                        (rx == bridge_cols[4]) || (rx == bridge_cols[5]);
                            if (ry < 4'd15) begin
                                map_we <= 1'b1;
                                map_waddr <= tile_addr(rx, ry);
                                map_wdata <= is_bridge ? TILE_BRIDGE : TILE_RIVER;
                            end
                        end
                        gen_idx <= gen_idx + 9'd1;
                    end else begin
                        gen_state <= GEN_BUILD;
                        gen_idx <= 9'd0;
                        gen_count <= 6'd0;
                        lfsr_advance;
                    end
                end

                GEN_BUILD: begin
                    if (gen_count < (6'd20 + {2'd0, level})) begin
                        if (gen_idx == 9'd0) begin
                            gen_bx <= 5'd2 + gen_lfsr[4:0] % 5'd16;
                            gen_by <= 4'd2 + gen_lfsr[8:5] % 4'd11;
                            gen_bw <= 3'd1 + gen_lfsr[10:9] % 3'd3;
                            gen_bh <= 3'd1 + gen_lfsr[12:11] % 3'd3;
                            gen_bi <= 3'd0;
                            gen_bj <= 3'd0;
                            gen_idx <= 9'd1;
                            lfsr_advance;
                        end else begin
                            begin : build_block
                                reg [4:0] bx_cur;
                                reg [3:0] by_cur;
                                reg [8:0] addr;
                                bx_cur = gen_bx + {2'd0, gen_bi};
                                by_cur = gen_by + {1'b0, gen_bj};
                                addr = tile_addr(bx_cur, by_cur);
                                if (bx_cur < 5'd18 && by_cur < 4'd13) begin
                                    if (tile_map[addr] == TILE_STREET) begin
                                        map_we <= 1'b1;
                                        map_waddr <= addr;
                                        map_wdata <= TILE_BUILDING;
                                    end
                                end
                            end
                            if (gen_bi < gen_bw - 3'd1) begin
                                gen_bi <= gen_bi + 3'd1;
                            end else if (gen_bj < gen_bh - 3'd1) begin
                                gen_bi <= 3'd0;
                                gen_bj <= gen_bj + 3'd1;
                            end else begin
                                gen_count <= gen_count + 6'd1;
                                gen_idx <= 9'd0;
                            end
                        end
                    end else begin
                        gen_state <= GEN_TREE;
                        gen_count <= 6'd0;
                        lfsr_advance;
                    end
                end

                GEN_TREE: begin
                    if (gen_count < 6'd32) begin
                        begin : tree_block
                            reg [4:0] tx;
                            reg [3:0] ty;
                            reg [8:0] addr;
                            tx = gen_lfsr[4:0] % 5'd20;
                            ty = gen_lfsr[8:5] % 4'd15;
                            addr = tile_addr(tx, ty);
                            if (tile_map[addr] == TILE_STREET && tx > 5'd1 && tx < 5'd18 &&
                                ty > 4'd1 && ty < 4'd13) begin
                                map_we <= 1'b1;
                                map_waddr <= addr;
                                map_wdata <= TILE_TREE;
                            end
                        end
                        gen_count <= gen_count + 6'd1;
                        lfsr_advance;
                    end else begin
                        gen_state <= GEN_SPAWN;
                        gen_idx <= 9'd0;
                    end
                end

                GEN_SPAWN: begin
                    // Phase 1: Clear player spawn (bottom-left 4x3)
                    if (gen_idx < 9'd12) begin
                        begin : spawn_block
                            reg [4:0] sx;
                            reg [3:0] sy;
                            sx = gen_idx[3:0] % 4'd4;
                            sy = 4'd12 + gen_idx[3:0] / 4'd4;
                            map_we <= 1'b1;
                            map_waddr <= tile_addr(sx, sy);
                            map_wdata <= TILE_STREET;
                        end
                        gen_idx <= gen_idx + 9'd1;
                    end
                    // Phase 2: Clear phone spawn (top-right 4x4)
                    else if (gen_idx < 9'd28) begin
                        begin : phone_block
                            reg [4:0] px;
                            reg [3:0] py;
                            reg [4:0] off;
                            off = gen_idx[4:0] - 5'd12;
                            px = 5'd16 + off[3:0] % 4'd4;
                            py = 4'd0 + off[3:0] / 4'd4;
                            map_we <= 1'b1;
                            map_waddr <= tile_addr(px, py);
                            map_wdata <= TILE_STREET;
                        end
                        gen_idx <= gen_idx + 9'd1;
                    end
                    // Phase 3: Clear bridge approaches (2 tiles above/below river for each bridge column group)
                    // Bridge columns: 5,6,7 and 13,14,15 — clear y from river_y-2 to river_y+4, x-1 to x+1
                    else if (gen_idx < 9'd100) begin
                        begin : bridge_clear
                            reg [6:0] bidx;
                            reg [2:0] bcol_group; // 0-5 = six bridge columns
                            reg [2:0] by_off;     // 0-6 = 7 rows to clear
                            reg [4:0] bx;
                            reg [3:0] by;
                            bidx = gen_idx[6:0] - 7'd28;
                            bcol_group = bidx / 7'd7;
                            by_off = bidx % 7'd7;
                            case (bcol_group)
                                3'd0: bx = 5'd5;
                                3'd1: bx = 5'd6;
                                3'd2: bx = 5'd7;
                                3'd3: bx = 5'd13;
                                3'd4: bx = 5'd14;
                                3'd5: bx = 5'd15;
                                default: bx = 5'd5;
                            endcase
                            by = (river_y >= 4'd2) ? (river_y - 4'd2 + {1'b0, by_off}) :
                                                     ({1'b0, by_off});
                            if (bcol_group < 3'd6 && by < 4'd15) begin
                                if (tile_map[tile_addr(bx, by)] != TILE_RIVER &&
                                    tile_map[tile_addr(bx, by)] != TILE_BRIDGE) begin
                                    map_we <= 1'b1;
                                    map_waddr <= tile_addr(bx, by);
                                    map_wdata <= TILE_STREET;
                                end
                            end
                        end
                        gen_idx <= gen_idx + 9'd1;
                    end
                    // Phase 4: Clear a vertical corridor at column 10 (guarantees north-south path through bridge)
                    else if (gen_idx < 9'd115) begin
                        begin : corridor
                            reg [3:0] cy;
                            cy = gen_idx[3:0] - 4'd4; // rows 0-14
                            if (cy < 4'd15) begin
                                if (tile_map[tile_addr(5'd10, cy)] == TILE_BUILDING ||
                                    tile_map[tile_addr(5'd10, cy)] == TILE_TREE) begin
                                    map_we <= 1'b1;
                                    map_waddr <= tile_addr(5'd10, cy);
                                    map_wdata <= TILE_STREET;
                                end
                            end
                        end
                        gen_idx <= gen_idx + 9'd1;
                    end
                    else begin
                        gen_state <= GEN_DONE;
                    end
                end

                GEN_DONE: begin
                    gen_done <= 1'b1;
                    gen_state <= GEN_IDLE;
                end

                default: gen_state <= GEN_IDLE;
            endcase
        end
    end

    integer i;
    initial begin
        for (i = 0; i < 300; i = i + 1) begin
            tile_map[i] = TILE_STREET;
        end
    end

endmodule
