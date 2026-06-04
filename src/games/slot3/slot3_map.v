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

    (* ram_style = "distributed" *) reg [2:0] tile_map [0:299];

    function [8:0] tile_addr;
        input [4:0] tx;
        input [3:0] ty;
        begin
            tile_addr = {ty, 4'b0000} + {1'b0, ty, 2'b00} + {4'b0000, tx};
        end
    endfunction

    function [2:0] template_tile;
        input [1:0] template_id;
        input [4:0] tx;
        input [3:0] ty;
        begin
            template_tile = TILE_STREET;

            if (tx == 5'd0 || tx == 5'd19 || ty == 4'd0 || ty == 4'd14)
                template_tile = TILE_BUILDING;

            case (template_id)
                2'd0: begin
                    if ((tx >= 5'd4 && tx <= 5'd6 && ty >= 4'd3 && ty <= 4'd8) ||
                        (tx >= 5'd11 && tx <= 5'd14 && ty >= 4'd6 && ty <= 4'd10))
                        template_tile = TILE_BUILDING;
                    if (ty == 4'd7 && tx >= 5'd2 && tx <= 5'd17)
                        template_tile = TILE_STREET;
                    if ((tx == 5'd9 || tx == 5'd10) && ty >= 4'd2 && ty <= 4'd12)
                        template_tile = TILE_STREET;
                    if ((tx == 5'd8 || tx == 5'd12) && (ty == 4'd4 || ty == 4'd10))
                        template_tile = TILE_TREE;
                end
                2'd1: begin
                    if ((tx >= 5'd3 && tx <= 5'd5 && ty >= 4'd2 && ty <= 4'd5) ||
                        (tx >= 5'd8 && tx <= 5'd10 && ty >= 4'd9 && ty <= 4'd12) ||
                        (tx >= 5'd13 && tx <= 5'd15 && ty >= 4'd3 && ty <= 4'd6))
                        template_tile = TILE_BUILDING;
                    if (tx == 5'd6 && ty >= 4'd2 && ty <= 4'd12)
                        template_tile = TILE_STREET;
                    if (ty == 4'd8 && tx >= 5'd2 && tx <= 5'd17)
                        template_tile = TILE_STREET;
                    if ((tx == 5'd11 && ty == 4'd4) || (tx == 5'd12 && ty == 4'd10))
                        template_tile = TILE_TREE;
                end
                default: begin
                    if ((tx >= 5'd4 && tx <= 5'd7 && ty >= 4'd4 && ty <= 4'd6) ||
                        (tx >= 5'd11 && tx <= 5'd15 && ty >= 4'd8 && ty <= 4'd10))
                        template_tile = TILE_BUILDING;
                    if (tx >= 5'd9 && tx <= 5'd10 && ty >= 4'd2 && ty <= 4'd12)
                        template_tile = TILE_STREET;
                    if (ty >= 4'd6 && ty <= 4'd7 && tx >= 5'd2 && tx <= 5'd17)
                        template_tile = TILE_STREET;
                    if ((tx == 5'd5 && ty == 4'd10) || (tx == 5'd14 && ty == 4'd4))
                        template_tile = TILE_TREE;
                end
            endcase
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

    assign walk0 = (query_x0 < 10'd640) && (query_y0 < 9'd480) && walkable_tile0;
    assign walk1 = (query_x1 < 10'd640) && (query_y1 < 9'd480) && walkable_tile1;
    assign walk2 = (query_x2 < 10'd640) && (query_y2 < 9'd480) && walkable_tile2;
    assign walk3 = (query_x3 < 10'd640) && (query_y3 < 9'd480) && walkable_tile3;
    assign render_tile = tile_map[tile_addr(render_tx, render_ty)];

    integer i;
    reg [1:0] template_id;
    reg [4:0] tx;
    reg [3:0] ty;

    always @(posedge clk) begin
        if (reset) begin
            gen_done <= 1'b0;
            river_y <= 4'd7;
            template_id <= 2'd0;
            for (i = 0; i < 300; i = i + 1) begin
                tile_map[i] <= TILE_STREET;
            end
        end else begin
            gen_done <= 1'b0;

            if (gen_start) begin
                template_id <= seed[1:0];
                river_y <= 4'd7;
                for (i = 0; i < 300; i = i + 1) begin
                    tx = i % 20;
                    ty = i / 20;
                    tile_map[i] <= template_tile(seed[1:0], tx, ty);
                end
                gen_done <= 1'b1;
            end

            if (destroy_en) begin
                tile_map[tile_addr(destroy_tx, destroy_ty)] <= TILE_STREET;
            end
        end
    end

endmodule
