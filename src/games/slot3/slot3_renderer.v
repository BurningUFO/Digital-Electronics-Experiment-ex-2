module slot3_renderer (
    input  wire        clk,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        display_active,
    input  wire        selected,
    input  wire [2:0]  state,
    input  wire [2:0]  render_tile,
    input  wire [7:0]  move_phase,
    input  wire [15:0] frame_count,
    input  wire [9:0]  neo_x,
    input  wire [8:0]  neo_y,
    input  wire [1:0]  neo_dir,
    input  wire [7:0]  attract_timer,
    input  wire [8:0]  bt_timer,
    input  wire [8:0]  cloak_timer,
    input  wire [5:0]  ammo,
    input  wire [2:0]  charges,
    input  wire [1:0]  emp_count,
    input  wire [1:0]  quest_phase,
    input  wire [2:0]  rescued,
    input  wire [2:0]  rescue_goal,
    input  wire        trinity_found,
    input  wire        terminal_hacked,
    input  wire [9:0]  smith_x0, smith_x1, smith_x2, smith_x3,
    input  wire [9:0]  smith_x4, smith_x5, smith_x6, smith_x7,
    input  wire [8:0]  smith_y0, smith_y1, smith_y2, smith_y3,
    input  wire [8:0]  smith_y4, smith_y5, smith_y6, smith_y7,
    input  wire [7:0]  smith_active,
    input  wire [7:0]  smith_chasing,
    input  wire [5:0]  smith_stun0, smith_stun1, smith_stun2, smith_stun3,
    input  wire [5:0]  smith_stun4, smith_stun5, smith_stun6, smith_stun7,
    input  wire [9:0]  npc_x0, npc_x1, npc_x2, npc_x3,
    input  wire [9:0]  npc_x4, npc_x5, npc_x6, npc_x7,
    input  wire [8:0]  npc_y0, npc_y1, npc_y2, npc_y3,
    input  wire [8:0]  npc_y4, npc_y5, npc_y6, npc_y7,
    input  wire [7:0]  npc_alive,
    input  wire [9:0]  red_x,
    input  wire [8:0]  red_y,
    input  wire [9:0]  trinity_x,
    input  wire [8:0]  trinity_y,
    input  wire [9:0]  terminal_x,
    input  wire [8:0]  terminal_y,
    input  wire [9:0]  phone_x,
    input  wire [8:0]  phone_y,
    input  wire [9:0]  bullet_x0, bullet_x1, bullet_x2, bullet_x3,
    input  wire [8:0]  bullet_y0, bullet_y1, bullet_y2, bullet_y3,
    input  wire [3:0]  bullet_active,
    input  wire [9:0]  bomb_x0, bomb_x1, bomb_x2, bomb_x3,
    input  wire [8:0]  bomb_y0, bomb_y1, bomb_y2, bomb_y3,
    input  wire [7:0]  bomb_timer0, bomb_timer1, bomb_timer2, bomb_timer3,
    input  wire [3:0]  bomb_active,
    input  wire [8:0]  emp_visual,
    input  wire [9:0]  pickup_x0, pickup_x1, pickup_x2, pickup_x3,
    input  wire [9:0]  pickup_x4, pickup_x5, pickup_x6, pickup_x7,
    input  wire [8:0]  pickup_y0, pickup_y1, pickup_y2, pickup_y3,
    input  wire [8:0]  pickup_y4, pickup_y5, pickup_y6, pickup_y7,
    input  wire [2:0]  pickup_type0, pickup_type1, pickup_type2, pickup_type3,
    input  wire [2:0]  pickup_type4, pickup_type5, pickup_type6, pickup_type7,
    input  wire [7:0]  pickup_active,
    input  wire [1:0]  menu_choice,
    input  wire [3:0]  start_difficulty,
    input  wire        pill_choice,
    input  wire [3:0]  level,
    input  wire        text_hit,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    localparam [2:0] ST_START = 3'd0;
    localparam [2:0] ST_PLAY  = 3'd1;
    localparam [2:0] ST_WIN   = 3'd3;
    localparam [2:0] ST_LOSE  = 3'd4;
    localparam [2:0] TILE_STREET   = 3'd0;
    localparam [2:0] TILE_RIVER    = 3'd1;
    localparam [2:0] TILE_BRIDGE   = 3'd2;
    localparam [2:0] TILE_BUILDING = 3'd3;
    localparam [2:0] TILE_TREE     = 3'd4;

    wire [9:0] smith_x [0:7];
    wire [8:0] smith_y [0:7];
    wire [5:0] smith_stun [0:7];
    wire [9:0] npc_x [0:7];
    wire [8:0] npc_y [0:7];
    wire [9:0] bullet_x [0:3];
    wire [8:0] bullet_y [0:3];
    wire [9:0] pickup_x [0:7];
    wire [8:0] pickup_y [0:7];

    assign smith_x[0]=smith_x0; assign smith_x[1]=smith_x1; assign smith_x[2]=smith_x2; assign smith_x[3]=smith_x3;
    assign smith_x[4]=smith_x4; assign smith_x[5]=smith_x5; assign smith_x[6]=smith_x6; assign smith_x[7]=smith_x7;
    assign smith_y[0]=smith_y0; assign smith_y[1]=smith_y1; assign smith_y[2]=smith_y2; assign smith_y[3]=smith_y3;
    assign smith_y[4]=smith_y4; assign smith_y[5]=smith_y5; assign smith_y[6]=smith_y6; assign smith_y[7]=smith_y7;
    assign smith_stun[0]=smith_stun0; assign smith_stun[1]=smith_stun1; assign smith_stun[2]=smith_stun2; assign smith_stun[3]=smith_stun3;
    assign smith_stun[4]=smith_stun4; assign smith_stun[5]=smith_stun5; assign smith_stun[6]=smith_stun6; assign smith_stun[7]=smith_stun7;
    assign npc_x[0]=npc_x0; assign npc_x[1]=npc_x1; assign npc_x[2]=npc_x2; assign npc_x[3]=npc_x3;
    assign npc_x[4]=npc_x4; assign npc_x[5]=npc_x5; assign npc_x[6]=npc_x6; assign npc_x[7]=npc_x7;
    assign npc_y[0]=npc_y0; assign npc_y[1]=npc_y1; assign npc_y[2]=npc_y2; assign npc_y[3]=npc_y3;
    assign npc_y[4]=npc_y4; assign npc_y[5]=npc_y5; assign npc_y[6]=npc_y6; assign npc_y[7]=npc_y7;
    assign bullet_x[0]=bullet_x0; assign bullet_x[1]=bullet_x1; assign bullet_x[2]=bullet_x2; assign bullet_x[3]=bullet_x3;
    assign bullet_y[0]=bullet_y0; assign bullet_y[1]=bullet_y1; assign bullet_y[2]=bullet_y2; assign bullet_y[3]=bullet_y3;
    assign pickup_x[0]=pickup_x0; assign pickup_x[1]=pickup_x1; assign pickup_x[2]=pickup_x2; assign pickup_x[3]=pickup_x3;
    assign pickup_x[4]=pickup_x4; assign pickup_x[5]=pickup_x5; assign pickup_x[6]=pickup_x6; assign pickup_x[7]=pickup_x7;
    assign pickup_y[0]=pickup_y0; assign pickup_y[1]=pickup_y1; assign pickup_y[2]=pickup_y2; assign pickup_y[3]=pickup_y3;
    assign pickup_y[4]=pickup_y4; assign pickup_y[5]=pickup_y5; assign pickup_y[6]=pickup_y6; assign pickup_y[7]=pickup_y7;

    reg [9:0] compass_target_x;
    reg [8:0] compass_target_y;
    always @(*) begin
        case (quest_phase)
            2'd0: begin compass_target_x = trinity_x; compass_target_y = trinity_y; end
            2'd1: begin compass_target_x = terminal_x; compass_target_y = terminal_y; end
            2'd2: begin compass_target_x = npc_x[0]; compass_target_y = npc_y[0]; end
            default: begin compass_target_x = phone_x; compass_target_y = phone_y; end
        endcase
    end

    wire signed [10:0] arrow_dx = $signed({1'b0, compass_target_x}) - $signed({1'b0, neo_x});
    wire signed [10:0] arrow_dy = $signed({2'b0, compass_target_y}) - $signed({2'b0, neo_y});
    wire [10:0] abs_dx = arrow_dx[10] ? (~arrow_dx + 11'd1) : arrow_dx;
    wire [10:0] abs_dy = arrow_dy[10] ? (~arrow_dy + 11'd1) : arrow_dy;
    reg [2:0] arrow_dir;
    always @(*) begin
        if (abs_dx > (abs_dy << 1)) arrow_dir = arrow_dx[10] ? 3'd6 : 3'd2;
        else if (abs_dy > (abs_dx << 1)) arrow_dir = arrow_dy[10] ? 3'd0 : 3'd4;
        else if (!arrow_dx[10] && !arrow_dy[10]) arrow_dir = 3'd3;
        else if (arrow_dx[10] && !arrow_dy[10]) arrow_dir = 3'd5;
        else if (!arrow_dx[10] && arrow_dy[10]) arrow_dir = 3'd1;
        else arrow_dir = 3'd7;
    end

    wire compass_region = display_active && (state == ST_PLAY) &&
                          (pixel_x >= 10'd600) && (pixel_x < 10'd616) &&
                          (pixel_y >= 10'd12) && (pixel_y < 10'd28);
    wire [3:0] ax = pixel_x - 10'd600;
    wire [3:0] ay = pixel_y - 10'd12;
    reg compass_pixel;
    always @(*) begin
        compass_pixel = 1'b0;
        if (compass_region) begin
            case (arrow_dir)
                3'd0: compass_pixel = (ax >= 4'd7 && ax <= 4'd8 && ay >= 4'd2 && ay <= 4'd13) || (ay == 4'd2 && ax >= 4'd5 && ax <= 4'd10);
                3'd2: compass_pixel = (ay >= 4'd7 && ay <= 4'd8 && ax >= 4'd2 && ax <= 4'd13) || (ax == 4'd13 && ay >= 4'd5 && ay <= 4'd10);
                3'd4: compass_pixel = (ax >= 4'd7 && ax <= 4'd8 && ay >= 4'd2 && ay <= 4'd13) || (ay == 4'd13 && ax >= 4'd5 && ax <= 4'd10);
                3'd6: compass_pixel = (ay >= 4'd7 && ay <= 4'd8 && ax >= 4'd2 && ax <= 4'd13) || (ax == 4'd2 && ay >= 4'd5 && ay <= 4'd10);
                default: compass_pixel = (ax == ay) || (ax + ay == 4'd15) || (ax == ay + 4'd1) || (ax + ay == 4'd14);
            endcase
        end
    end

    reg smith_on, npc_on, bullet_on, pickup_on;
    reg [3:0] smith_lx, npc_lx, neo_lx, pickup_lx;
    reg [4:0] smith_ly, npc_ly, neo_ly, pickup_ly;
    reg smith_is_chasing, smith_is_stunned;
    integer i;
    always @(*) begin
        smith_on = 1'b0;
        smith_lx = 4'd0;
        smith_ly = 5'd0;
        smith_is_chasing = 1'b0;
        smith_is_stunned = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!smith_on && smith_active[i] &&
                pixel_x >= smith_x[i] && pixel_x < smith_x[i] + 10'd16 &&
                pixel_y >= smith_y[i] && pixel_y < smith_y[i] + 9'd20) begin
                smith_on = 1'b1;
                smith_lx = pixel_x - smith_x[i];
                smith_ly = pixel_y - smith_y[i];
                smith_is_chasing = smith_chasing[i];
                smith_is_stunned = (smith_stun[i] != 6'd0);
            end
        end

        npc_on = 1'b0;
        npc_lx = 4'd0;
        npc_ly = 5'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!npc_on && npc_alive[i] &&
                pixel_x >= npc_x[i] && pixel_x < npc_x[i] + 10'd15 &&
                pixel_y >= npc_y[i] && pixel_y < npc_y[i] + 9'd19) begin
                npc_on = 1'b1;
                npc_lx = pixel_x - npc_x[i];
                npc_ly = pixel_y - npc_y[i];
            end
        end

        bullet_on = 1'b0;
        for (i = 0; i < 2; i = i + 1) begin
            if (!bullet_on && bullet_active[i] &&
                pixel_x >= bullet_x[i] && pixel_x < bullet_x[i] + 10'd6 &&
                pixel_y >= bullet_y[i] && pixel_y < bullet_y[i] + 9'd6) begin
                bullet_on = 1'b1;
            end
        end

        pickup_on = 1'b0;
        pickup_lx = 4'd0;
        pickup_ly = 5'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!pickup_on && pickup_active[i] &&
                pixel_x >= pickup_x[i] && pixel_x < pickup_x[i] + 10'd14 &&
                pixel_y >= pickup_y[i] && pixel_y < pickup_y[i] + 9'd14) begin
                pickup_on = 1'b1;
                pickup_lx = pixel_x - pickup_x[i];
                pickup_ly = pixel_y - pickup_y[i];
            end
        end
    end

    wire neo_on = display_active &&
                  pixel_x >= neo_x && pixel_x < neo_x + 10'd16 &&
                  pixel_y >= neo_y && pixel_y < neo_y + 9'd20;
    always @(*) begin
        neo_lx = pixel_x - neo_x;
        neo_ly = pixel_y - neo_y;
    end
    wire trinity_on = display_active && pixel_x >= trinity_x && pixel_x < trinity_x + 10'd16 &&
                      pixel_y >= trinity_y && pixel_y < trinity_y + 9'd20;
    wire red_on = display_active && pixel_x >= red_x && pixel_x < red_x + 10'd16 &&
                  pixel_y >= red_y && pixel_y < red_y + 9'd20;
    wire terminal_on = display_active && pixel_x >= terminal_x && pixel_x < terminal_x + 10'd24 &&
                       pixel_y >= terminal_y && pixel_y < terminal_y + 9'd24;
    wire phone_on = display_active && pixel_x >= phone_x && pixel_x < phone_x + 10'd24 &&
                    pixel_y >= phone_y && pixel_y < phone_y + 9'd36;
    wire hud_on = display_active && (pixel_y >= 9'd456);

    function [11:0] tile_color;
        input [2:0] tile;
        input [4:0] lx;
        input [4:0] ly;
        begin
            case (tile)
                TILE_STREET:   tile_color = (lx[2] ^ ly[2]) ? 12'h132 : 12'h021;
                TILE_RIVER:    tile_color = (lx[1] ^ ly[1]) ? 12'h08B : 12'h059;
                TILE_BRIDGE:   tile_color = (lx[2] ^ ly[2]) ? 12'h975 : 12'h753;
                TILE_BUILDING: tile_color = (lx[3] || ly[3]) ? 12'h444 : 12'h666;
                default:       tile_color = (lx[0] ^ ly[0]) ? 12'h284 : 12'h173;
            endcase
        end
    endfunction

    task draw_humanoid;
        input [3:0] lx;
        input [4:0] ly;
        input [11:0] outline;
        input [11:0] body;
        input [11:0] highlight;
        begin
            if (lx == 4'd0 || lx == 4'd15 || ly == 5'd0 || ly == 5'd19) begin
                {vga_r, vga_g, vga_b} = outline;
            end else if (ly <= 5'd4 && lx >= 4'd4 && lx <= 4'd11) begin
                {vga_r, vga_g, vga_b} = highlight;
            end else if (ly <= 5'd15 && lx >= 4'd4 && lx <= 4'd11) begin
                {vga_r, vga_g, vga_b} = body;
            end else if (ly >= 5'd6 && ly <= 5'd14 && (lx <= 4'd3 || lx >= 4'd12)) begin
                {vga_r, vga_g, vga_b} = outline;
            end else if (ly >= 5'd16 && ((lx >= 4'd3 && lx <= 4'd5) || (lx >= 4'd10 && lx <= 4'd12))) begin
                {vga_r, vga_g, vga_b} = outline;
            end
        end
    endtask

    wire [11:0] base_tile_color = tile_color(render_tile, pixel_x[4:0], pixel_y[4:0]);

    always @(*) begin
        vga_r = 4'h0;
        vga_g = 4'h0;
        vga_b = 4'h0;

        if (!display_active || !selected) begin
            vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        end else if (state == ST_START || state == ST_WIN || state == ST_LOSE) begin
            vga_r = 4'h0; vga_g = 4'h1; vga_b = 4'h0;
            if (text_hit) begin
                if (state == ST_LOSE) begin
                    vga_r = 4'hF; vga_g = 4'h2; vga_b = 4'h2;
                end else begin
                    vga_r = 4'h2; vga_g = 4'hF; vga_b = 4'h6;
                end
            end
        end else begin
            {vga_r, vga_g, vga_b} = base_tile_color;

            if (pickup_on) begin
                vga_r = 4'hF; vga_g = 4'hD; vga_b = 4'h4;
                if (pickup_lx == 4'd0 || pickup_lx == 4'd13 || pickup_ly == 5'd0 || pickup_ly == 5'd13) begin
                    vga_r = 4'h7; vga_g = 4'h5; vga_b = 4'h1;
                end
            end

            if (terminal_on) begin
                vga_r = terminal_hacked ? 4'h4 : 4'hC;
                vga_g = terminal_hacked ? 4'hF : 4'hF;
                vga_b = terminal_hacked ? 4'h8 : 4'h4;
            end
            if (phone_on) begin
                vga_r = 4'h1; vga_g = 4'hD; vga_b = 4'hF;
            end

            if (npc_on) begin
                draw_humanoid(npc_lx, npc_ly, 12'h112, 12'h789, 12'hDB9);
            end
            if (red_on) begin
                draw_humanoid(pixel_x - red_x, pixel_y - red_y, 12'h300, 12'hD24, 12'hFBA);
            end
            if (trinity_on) begin
                draw_humanoid(pixel_x - trinity_x, pixel_y - trinity_y, 12'h031, 12'h153, 12'hBC8);
            end
            if (smith_on) begin
                if (smith_is_stunned) draw_humanoid(smith_lx, smith_ly, 12'h134, 12'h467, 12'hBCA);
                else if (smith_is_chasing) draw_humanoid(smith_lx, smith_ly, 12'h300, 12'h411, 12'hECB);
                else draw_humanoid(smith_lx, smith_ly, 12'h111, 12'h222, 12'hDCA);
            end
            if (bullet_on) begin
                vga_r = 4'hE; vga_g = 4'hF; vga_b = 4'h7;
            end
            if (neo_on) begin
                case (neo_dir)
                    2'd0: draw_humanoid(neo_lx, neo_ly, 12'h021, 12'h053, 12'hCDA);
                    2'd1: draw_humanoid(neo_lx, neo_ly, 12'h032, 12'h064, 12'hDEC);
                    2'd2: draw_humanoid(neo_lx, neo_ly, 12'h021, 12'h052, 12'hBCA);
                    default: draw_humanoid(neo_lx, neo_ly, 12'h010, 12'h042, 12'hBC9);
                endcase
            end

            if (compass_pixel) begin
                vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
            end
            if (bt_timer != 9'd0 && (pixel_x[4:0] == 5'd0 || pixel_y[4:0] == 5'd0)) begin
                vga_g = vga_g | 4'h4;
            end
            if (attract_timer != 8'd0 && pixel_x[3:0] == 4'd0) begin
                vga_r = vga_r | 4'h3;
            end
            if (hud_on) begin
                vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                if (text_hit) begin
                    vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
                end
                if (pixel_y >= 10'd460 && pixel_y < 10'd467) begin
                    if (pixel_x >= 10'd368 && pixel_x < 10'd373 && hud_digit_pixel(ammo / 10, pixel_x - 10'd368, pixel_y - 10'd460)) begin
                        vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'h6;
                    end
                    if (pixel_x >= 10'd374 && pixel_x < 10'd379 && hud_digit_pixel(ammo % 10, pixel_x - 10'd374, pixel_y - 10'd460)) begin
                        vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'h6;
                    end
                    if (pixel_x >= 10'd448 && pixel_x < 10'd453 && hud_digit_pixel({1'b0, rescued}, pixel_x - 10'd448, pixel_y - 10'd460)) begin
                        vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
                    end
                    if (pixel_x >= 10'd458 && pixel_x < 10'd463 && hud_digit_pixel({1'b0, rescue_goal}, pixel_x - 10'd458, pixel_y - 10'd460)) begin
                        vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
                    end
                end
            end
        end
    end

    function hud_digit_pixel;
        input [3:0] digit;
        input [3:0] col;
        input [2:0] row;
        reg [4:0] bits;
        begin
            bits = 5'b00000;
            case (digit)
                4'd0: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b10001; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b11111; endcase
                4'd1: case (row) 3'd0: bits=5'b00100; 3'd1: bits=5'b01100; 3'd2: bits=5'b00100; 3'd3: bits=5'b00100; 3'd4: bits=5'b00100; 3'd5: bits=5'b00100; 3'd6: bits=5'b01110; endcase
                4'd2: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b00001; 3'd2: bits=5'b00001; 3'd3: bits=5'b11111; 3'd4: bits=5'b10000; 3'd5: bits=5'b10000; 3'd6: bits=5'b11111; endcase
                4'd3: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b00001; 3'd2: bits=5'b00001; 3'd3: bits=5'b01111; 3'd4: bits=5'b00001; 3'd5: bits=5'b00001; 3'd6: bits=5'b11111; endcase
                4'd4: case (row) 3'd0: bits=5'b10001; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b11111; 3'd4: bits=5'b00001; 3'd5: bits=5'b00001; 3'd6: bits=5'b00001; endcase
                4'd5: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b10000; 3'd2: bits=5'b10000; 3'd3: bits=5'b11111; 3'd4: bits=5'b00001; 3'd5: bits=5'b00001; 3'd6: bits=5'b11111; endcase
                4'd6: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b10000; 3'd2: bits=5'b10000; 3'd3: bits=5'b11111; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b11111; endcase
                4'd7: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b00001; 3'd2: bits=5'b00010; 3'd3: bits=5'b00100; 3'd4: bits=5'b01000; 3'd5: bits=5'b01000; 3'd6: bits=5'b01000; endcase
                4'd8: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b11111; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b11111; endcase
                default: case (row) 3'd0: bits=5'b11111; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b11111; 3'd4: bits=5'b00001; 3'd5: bits=5'b00001; 3'd6: bits=5'b11111; endcase
            endcase
            hud_digit_pixel = (col < 4'd5) && bits[4 - col[2:0]];
        end
    endfunction

endmodule
