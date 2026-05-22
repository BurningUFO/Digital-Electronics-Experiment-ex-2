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
    // Player
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
    // Entities
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
    // Combat
    input  wire [9:0]  bullet_x0, bullet_x1, bullet_x2, bullet_x3,
    input  wire [8:0]  bullet_y0, bullet_y1, bullet_y2, bullet_y3,
    input  wire [3:0]  bullet_active,
    input  wire [9:0]  bomb_x0, bomb_x1, bomb_x2, bomb_x3,
    input  wire [8:0]  bomb_y0, bomb_y1, bomb_y2, bomb_y3,
    input  wire [7:0]  bomb_timer0, bomb_timer1, bomb_timer2, bomb_timer3,
    input  wire [3:0]  bomb_active,
    input  wire [8:0]  emp_visual,
    // Pickups
    input  wire [9:0]  pickup_x0, pickup_x1, pickup_x2, pickup_x3,
    input  wire [9:0]  pickup_x4, pickup_x5, pickup_x6, pickup_x7,
    input  wire [8:0]  pickup_y0, pickup_y1, pickup_y2, pickup_y3,
    input  wire [8:0]  pickup_y4, pickup_y5, pickup_y6, pickup_y7,
    input  wire [2:0]  pickup_type0, pickup_type1, pickup_type2, pickup_type3,
    input  wire [2:0]  pickup_type4, pickup_type5, pickup_type6, pickup_type7,
    input  wire [7:0]  pickup_active,
    // Menu
    input  wire [1:0]  menu_choice,
    input  wire [3:0]  start_difficulty,
    input  wire        pill_choice,
    input  wire [3:0]  level,
    // Text
    input  wire        text_hit,
    // Output
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    // Reconstruct internal arrays from flat ports
    wire [9:0] smith_x [0:7];
    wire [8:0] smith_y [0:7];
    wire [5:0] smith_stun [0:7];
    wire [9:0] npc_x [0:7];
    wire [8:0] npc_y [0:7];
    wire [9:0] bullet_x [0:3];
    wire [8:0] bullet_y [0:3];
    wire [9:0] bomb_x [0:3];
    wire [8:0] bomb_y [0:3];
    wire [7:0] bomb_timer [0:3];
    wire [9:0] pickup_x [0:7];
    wire [8:0] pickup_y [0:7];
    wire [2:0] pickup_type [0:7];

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
    assign bomb_x[0]=bomb_x0; assign bomb_x[1]=bomb_x1; assign bomb_x[2]=bomb_x2; assign bomb_x[3]=bomb_x3;
    assign bomb_y[0]=bomb_y0; assign bomb_y[1]=bomb_y1; assign bomb_y[2]=bomb_y2; assign bomb_y[3]=bomb_y3;
    assign bomb_timer[0]=bomb_timer0; assign bomb_timer[1]=bomb_timer1; assign bomb_timer[2]=bomb_timer2; assign bomb_timer[3]=bomb_timer3;
    assign pickup_x[0]=pickup_x0; assign pickup_x[1]=pickup_x1; assign pickup_x[2]=pickup_x2; assign pickup_x[3]=pickup_x3;
    assign pickup_x[4]=pickup_x4; assign pickup_x[5]=pickup_x5; assign pickup_x[6]=pickup_x6; assign pickup_x[7]=pickup_x7;
    assign pickup_y[0]=pickup_y0; assign pickup_y[1]=pickup_y1; assign pickup_y[2]=pickup_y2; assign pickup_y[3]=pickup_y3;
    assign pickup_y[4]=pickup_y4; assign pickup_y[5]=pickup_y5; assign pickup_y[6]=pickup_y6; assign pickup_y[7]=pickup_y7;
    assign pickup_type[0]=pickup_type0; assign pickup_type[1]=pickup_type1; assign pickup_type[2]=pickup_type2; assign pickup_type[3]=pickup_type3;
    assign pickup_type[4]=pickup_type4; assign pickup_type[5]=pickup_type5; assign pickup_type[6]=pickup_type6; assign pickup_type[7]=pickup_type7;

    localparam [2:0] ST_START = 3'd0;
    localparam [2:0] ST_PLAY  = 3'd1;
    localparam [2:0] ST_PILL  = 3'd2;
    localparam [2:0] ST_WIN   = 3'd3;
    localparam [2:0] ST_LOSE  = 3'd4;

    localparam [2:0] TILE_STREET   = 3'd0;
    localparam [2:0] TILE_RIVER    = 3'd1;
    localparam [2:0] TILE_BRIDGE   = 3'd2;
    localparam [2:0] TILE_BUILDING = 3'd3;
    localparam [2:0] TILE_TREE     = 3'd4;

    wire [4:0] tile_lx = pixel_x[4:0];
    wire [4:0] tile_ly = pixel_y[4:0];

    // Rain effect
    wire [9:0] rain_sum = pixel_y + {1'b0, move_phase, 1'b0};
    wire rain_on = (rain_sum[4:0] < 5'd8) &&
                   (((pixel_x[8:2] ^ pixel_y[7:1] ^ {1'b0, move_phase[7:2]}) & 7'd15) == 7'd0);

    // Compass arrow - points toward current objective
    // Target selection based on quest phase
    reg [9:0] compass_target_x;
    reg [8:0] compass_target_y;
    always @(*) begin
        case (quest_phase)
            2'd0: begin compass_target_x = trinity_x; compass_target_y = trinity_y; end
            2'd1: begin compass_target_x = terminal_x; compass_target_y = terminal_y; end
            2'd2: begin compass_target_x = npc_x[0]; compass_target_y = npc_y[0]; end
            2'd3: begin compass_target_x = phone_x; compass_target_y = phone_y; end
        endcase
    end

    // Direction: 0=N,1=NE,2=E,3=SE,4=S,5=SW,6=W,7=NW
    wire signed [10:0] arrow_dx = $signed({1'b0, compass_target_x}) - $signed({1'b0, neo_x});
    wire signed [10:0] arrow_dy = $signed({2'b0, compass_target_y}) - $signed({2'b0, neo_y});
    wire [10:0] abs_dx = arrow_dx[10] ? (~arrow_dx + 11'd1) : arrow_dx;
    wire [10:0] abs_dy = arrow_dy[10] ? (~arrow_dy + 11'd1) : arrow_dy;
    wire mostly_horiz = (abs_dx > {abs_dy[9:0], 1'b0}); // dx > 2*dy
    wire mostly_vert  = (abs_dy > {abs_dx[9:0], 1'b0}); // dy > 2*dx

    reg [2:0] arrow_dir;
    always @(*) begin
        if (mostly_vert && !arrow_dy[10])       arrow_dir = 3'd4; // S
        else if (mostly_vert && arrow_dy[10])    arrow_dir = 3'd0; // N
        else if (mostly_horiz && !arrow_dx[10])  arrow_dir = 3'd2; // E
        else if (mostly_horiz && arrow_dx[10])   arrow_dir = 3'd6; // W
        else if (!arrow_dx[10] && !arrow_dy[10]) arrow_dir = 3'd3; // SE
        else if (arrow_dx[10] && !arrow_dy[10])  arrow_dir = 3'd5; // SW
        else if (!arrow_dx[10] && arrow_dy[10])  arrow_dir = 3'd1; // NE
        else                                      arrow_dir = 3'd7; // NW
    end

    // Arrow drawn at top-right (600,12) in a 16x16 box
    wire compass_region = display_active && (state == ST_PLAY) &&
                          (pixel_x >= 10'd600) && (pixel_x < 10'd616) &&
                          (pixel_y >= 10'd12) && (pixel_y < 10'd28);
    wire [3:0] ax = pixel_x - 10'd600;
    wire [3:0] ay = pixel_y - 10'd12;

    // Arrow pixel pattern based on direction
    reg compass_pixel;
    always @(*) begin
        compass_pixel = 1'b0;
        if (compass_region) begin
            case (arrow_dir)
                3'd0: // N (up arrow)
                    compass_pixel = (ax >= 4'd7 && ax <= 4'd8 && ay >= 4'd2 && ay <= 4'd13) ||
                                    (ay == 4'd2 && ax >= 4'd5 && ax <= 4'd10) ||
                                    (ay == 4'd3 && ax >= 4'd6 && ax <= 4'd9);
                3'd4: // S (down arrow)
                    compass_pixel = (ax >= 4'd7 && ax <= 4'd8 && ay >= 4'd2 && ay <= 4'd13) ||
                                    (ay == 4'd13 && ax >= 4'd5 && ax <= 4'd10) ||
                                    (ay == 4'd12 && ax >= 4'd6 && ax <= 4'd9);
                3'd2: // E (right arrow)
                    compass_pixel = (ay >= 4'd7 && ay <= 4'd8 && ax >= 4'd2 && ax <= 4'd13) ||
                                    (ax == 4'd13 && ay >= 4'd5 && ay <= 4'd10) ||
                                    (ax == 4'd12 && ay >= 4'd6 && ay <= 4'd9);
                3'd6: // W (left arrow)
                    compass_pixel = (ay >= 4'd7 && ay <= 4'd8 && ax >= 4'd2 && ax <= 4'd13) ||
                                    (ax == 4'd2 && ay >= 4'd5 && ay <= 4'd10) ||
                                    (ax == 4'd3 && ay >= 4'd6 && ay <= 4'd9);
                3'd1: // NE
                    compass_pixel = (ax == ay) || (ax == ay + 4'd1) ||
                                    (ay <= 4'd3 && ax >= 4'd11) ||
                                    (ax >= 4'd12 && ay <= 4'd4);
                3'd3: // SE
                    compass_pixel = (ax + ay == 4'd15) || (ax + ay == 4'd14) ||
                                    (ay >= 4'd12 && ax >= 4'd11) ||
                                    (ax >= 4'd12 && ay >= 4'd11);
                3'd5: // SW
                    compass_pixel = (ax == ay) || (ax + 4'd1 == ay) ||
                                    (ay >= 4'd12 && ax <= 4'd4) ||
                                    (ax <= 4'd3 && ay >= 4'd11);
                3'd7: // NW
                    compass_pixel = (ax + ay == 4'd15) || (ax + ay == 4'd14) ||
                                    (ay <= 4'd3 && ax <= 4'd4) ||
                                    (ax <= 4'd3 && ay <= 4'd4);
            endcase
        end
    end

    // Entity overlap detection
    wire neo_on = display_active &&
                  (pixel_x >= neo_x) && (pixel_x < neo_x + 10'd16) &&
                  (pixel_y >= neo_y) && (pixel_y < neo_y + 9'd20);
    wire [3:0] neo_lx = pixel_x - neo_x;
    wire [4:0] neo_ly = pixel_y - neo_y;

    wire phone_on = display_active && trinity_found &&
                    (pixel_x >= phone_x) && (pixel_x < phone_x + 10'd32) &&
                    (pixel_y >= phone_y) && (pixel_y < phone_y + 9'd46);

    wire terminal_on = display_active &&
                       (pixel_x >= terminal_x) && (pixel_x < terminal_x + 10'd24) &&
                       (pixel_y >= terminal_y) && (pixel_y < terminal_y + 9'd24);

    wire red_on = display_active &&
                  (pixel_x >= red_x) && (pixel_x < red_x + 10'd16) &&
                  (pixel_y >= red_y) && (pixel_y < red_y + 9'd20);

    wire trinity_on = display_active &&
                      (pixel_x >= trinity_x) && (pixel_x < trinity_x + 10'd16) &&
                      (pixel_y >= trinity_y) && (pixel_y < trinity_y + 9'd20);

    // Smith detection (first match)
    reg smith_on;
    reg [3:0] smith_lx;
    reg [4:0] smith_ly;
    reg smith_is_chasing;
    reg smith_is_stunned;
    integer si;
    always @(*) begin
        smith_on = 1'b0;
        smith_lx = 4'd0;
        smith_ly = 5'd0;
        smith_is_chasing = 1'b0;
        smith_is_stunned = 1'b0;
        for (si = 0; si < 8; si = si + 1) begin
            if (!smith_on && smith_active[si] && display_active &&
                pixel_x >= smith_x[si] && pixel_x < smith_x[si] + 10'd16 &&
                pixel_y >= smith_y[si] && pixel_y < smith_y[si] + 9'd20) begin
                smith_on = 1'b1;
                smith_lx = pixel_x - smith_x[si];
                smith_ly = pixel_y - smith_y[si];
                smith_is_chasing = smith_chasing[si];
                smith_is_stunned = (smith_stun[si] != 6'd0);
            end
        end
    end

    // NPC detection
    reg npc_on;
    reg [3:0] npc_lx;
    reg [4:0] npc_ly;
    integer ni;
    always @(*) begin
        npc_on = 1'b0;
        npc_lx = 4'd0;
        npc_ly = 5'd0;
        for (ni = 0; ni < 8; ni = ni + 1) begin
            if (!npc_on && npc_alive[ni] && display_active &&
                pixel_x >= npc_x[ni] && pixel_x < npc_x[ni] + 10'd15 &&
                pixel_y >= npc_y[ni] && pixel_y < npc_y[ni] + 9'd19) begin
                npc_on = 1'b1;
                npc_lx = pixel_x - npc_x[ni];
                npc_ly = pixel_y - npc_y[ni];
            end
        end
    end

    // Bullet detection
    reg bullet_on;
    integer bi;
    always @(*) begin
        bullet_on = 1'b0;
        for (bi = 0; bi < 4; bi = bi + 1) begin
            if (!bullet_on && bullet_active[bi] && display_active &&
                pixel_x >= bullet_x[bi] && pixel_x < bullet_x[bi] + 10'd6 &&
                pixel_y >= bullet_y[bi] && pixel_y < bullet_y[bi] + 9'd6) begin
                bullet_on = 1'b1;
            end
        end
    end

    // Bomb detection
    reg bomb_on;
    reg bomb_flash;
    integer boi;
    always @(*) begin
        bomb_on = 1'b0;
        bomb_flash = 1'b0;
        for (boi = 0; boi < 4; boi = boi + 1) begin
            if (!bomb_on && bomb_active[boi] && display_active &&
                pixel_x >= bomb_x[boi] && pixel_x < bomb_x[boi] + 10'd16 &&
                pixel_y >= bomb_y[boi] && pixel_y < bomb_y[boi] + 9'd16) begin
                bomb_on = 1'b1;
                bomb_flash = (bomb_timer[boi] < 8'd35) && frame_count[2];
            end
        end
    end

    // Pickup detection
    reg pickup_on;
    reg [2:0] pickup_cur_type;
    integer pi;
    always @(*) begin
        pickup_on = 1'b0;
        pickup_cur_type = 3'd0;
        for (pi = 0; pi < 8; pi = pi + 1) begin
            if (!pickup_on && pickup_active[pi] && display_active &&
                pixel_x >= pickup_x[pi] && pixel_x < pickup_x[pi] + 10'd18 &&
                pixel_y >= pickup_y[pi] && pixel_y < pickup_y[pi] + 9'd18) begin
                pickup_on = 1'b1;
                pickup_cur_type = pickup_type[pi];
            end
        end
    end

    // HUD bar at bottom
    wire hud_on = display_active && (pixel_y >= 9'd456);
    wire bt_bar_on = display_active && (pixel_y >= 9'd2) && (pixel_y < 9'd6) &&
                     (pixel_x < {1'b0, bt_timer});

    // Main pixel output
    always @(*) begin
        vga_r = 4'h0;
        vga_g = 4'h0;
        vga_b = 4'h0;

        if (!display_active || !selected) begin
            vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        end else if (state == ST_START || state == ST_WIN || state == ST_LOSE) begin
            // Dark background with rain
            vga_g = rain_on ? 4'h3 : 4'h0;
            if (text_hit) begin
                if (state == ST_LOSE) begin
                    vga_r = 4'hF; vga_g = 4'h2; vga_b = 4'h2;
                end else begin
                    vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'h4;
                end
            end
            // Menu highlight
            if (state == ST_START) begin
                if ((menu_choice == 2'd0 && pixel_y >= 9'd232 && pixel_y < 9'd290 && pixel_x >= 10'd130 && pixel_x < 10'd510) ||
                    (menu_choice == 2'd1 && pixel_y >= 9'd312 && pixel_y < 9'd370 && pixel_x >= 10'd130 && pixel_x < 10'd510) ||
                    (menu_choice == 2'd2 && pixel_y >= 9'd392 && pixel_y < 9'd450 && pixel_x >= 10'd130 && pixel_x < 10'd510)) begin
                    if (pixel_x[2] ^ pixel_y[2]) begin
                        vga_r = 4'h0; vga_g = 4'h4; vga_b = 4'h2;
                    end
                end
            end
        end else if (state == ST_PILL) begin
            vga_r = 4'h0; vga_g = 4'h1; vga_b = 4'h0;
            // Red pill left
            if (pixel_x >= 10'd180 && pixel_x < 10'd280 && pixel_y >= 9'd200 && pixel_y < 9'd280) begin
                vga_r = 4'hC; vga_g = 4'h1; vga_b = 4'h2;
            end
            // Blue pill right
            if (pixel_x >= 10'd360 && pixel_x < 10'd460 && pixel_y >= 9'd200 && pixel_y < 9'd280) begin
                vga_r = 4'h1; vga_g = 4'h3; vga_b = 4'hD;
            end
            // Selection highlight
            if ((pill_choice == 1'b0 && pixel_x >= 10'd172 && pixel_x < 10'd288 && pixel_y >= 9'd192 && pixel_y < 9'd288) ||
                (pill_choice == 1'b1 && pixel_x >= 10'd352 && pixel_x < 10'd468 && pixel_y >= 9'd192 && pixel_y < 9'd288)) begin
                if (pixel_x[2] ^ pixel_y[2]) begin
                    vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
                end
            end
            if (text_hit) begin
                vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'h4;
            end
        end else begin
            // PLAY state - game rendering
            // Layer 0: Tile background
            case (render_tile)
                TILE_RIVER: begin
                    vga_r = 4'h0; vga_g = 4'h3; vga_b = 4'h8;
                end
                TILE_BRIDGE: begin
                    vga_r = 4'h8; vga_g = 4'h5; vga_b = 4'h2;
                end
                TILE_BUILDING: begin
                    vga_r = 4'h4; vga_g = 4'h5; vga_b = 4'h5;
                    if (tile_lx[3] && tile_ly[3]) begin
                        vga_r = 4'hB; vga_g = 4'hD; vga_b = 4'hB;
                    end
                end
                TILE_TREE: begin
                    vga_r = 4'h1; vga_g = 4'h5; vga_b = 4'h2;
                end
                default: begin
                    vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h2;
                    if (tile_lx == 5'd0 || tile_ly == 5'd0) begin
                        vga_r = 4'h2; vga_g = 4'h2; vga_b = 4'h2;
                    end
                end
            endcase

            // Layer 1: Pickups
            if (pickup_on) begin
                case (pickup_cur_type)
                    3'd0: begin vga_r = 4'hD; vga_g = 4'hF; vga_b = 4'hE; end // gun
                    3'd1: begin vga_r = 4'hF; vga_g = 4'hC; vga_b = 4'h4; end // ammo
                    3'd2: begin vga_r = 4'hF; vga_g = 4'h8; vga_b = 4'h2; end // charge
                    3'd3: begin vga_r = 4'h6; vga_g = 4'hF; vga_b = 4'hF; end // emp
                    3'd4: begin vga_r = 4'hA; vga_g = 4'h7; vga_b = 4'hF; end // cloak
                    3'd5: begin vga_r = 4'hD; vga_g = 4'hC; vga_b = 4'h8; end // map
                    3'd6: begin vga_r = 4'h1; vga_g = 4'hC; vga_b = 4'hF; end // phonecard
                    default: begin vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF; end
                endcase
            end

            // Layer 2: Phone & Terminal
            if (terminal_on) begin
                vga_r = terminal_hacked ? 4'h4 : 4'hF;
                vga_g = terminal_hacked ? 4'hF : 4'hC;
                vga_b = terminal_hacked ? 4'h6 : 4'h4;
            end
            if (phone_on) begin
                vga_r = 4'h1; vga_g = 4'hC; vga_b = 4'hF;
            end

            // Layer 3: NPCs - civilian person sprite
            if (npc_on) begin
                if (npc_ly < 5'd5 && npc_lx >= 4'd4 && npc_lx <= 4'd10) begin
                    // Head (skin)
                    vga_r = 4'hD; vga_g = 4'hB; vga_b = 4'h8;
                end else if (npc_ly >= 5'd5 && npc_ly <= 5'd15 && npc_lx >= 4'd3 && npc_lx <= 4'd11) begin
                    // Body (gray-blue coat)
                    vga_r = 4'h7; vga_g = 4'h8; vga_b = 4'h9;
                end else if (npc_ly >= 5'd7 && npc_ly <= 5'd14 && (npc_lx <= 4'd2 || npc_lx >= 4'd12)) begin
                    // Arms
                    vga_r = 4'h6; vga_g = 4'h7; vga_b = 4'h8;
                end else if (npc_ly >= 5'd16 && ((npc_lx >= 4'd2 && npc_lx <= 4'd5) || (npc_lx >= 4'd9 && npc_lx <= 4'd12))) begin
                    // Feet
                    vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h1;
                end
            end

            // Layer 4: Red Woman & Trinity - detailed person sprites
            if (red_on) begin : red_sprite
                reg [3:0] rlx;
                reg [4:0] rly;
                rlx = pixel_x - red_x;
                rly = pixel_y - red_y;
                if (rly < 5'd5 && rlx >= 4'd5 && rlx <= 4'd10) begin
                    // Head
                    vga_r = 4'hF; vga_g = 4'hC; vga_b = 4'h9;
                end else if (rly >= 5'd5 && rly <= 5'd16 && rlx >= 4'd3 && rlx <= 4'd12) begin
                    // Red dress
                    vga_r = 4'hE; vga_g = 4'h2; vga_b = 4'h3;
                end else if (rly >= 5'd7 && rly <= 5'd14 && (rlx <= 4'd2 || rlx >= 4'd13)) begin
                    // Arms (skin)
                    vga_r = 4'hF; vga_g = 4'hC; vga_b = 4'h9;
                end else if (rly >= 5'd17 && rlx >= 4'd4 && rlx <= 4'd11) begin
                    // Feet
                    vga_r = 4'hA; vga_g = 4'h1; vga_b = 4'h1;
                end
            end
            if (trinity_on) begin : trinity_sprite
                reg [3:0] tlx;
                reg [4:0] tly;
                tlx = pixel_x - trinity_x;
                tly = pixel_y - trinity_y;
                if (tly < 5'd5 && tlx >= 4'd5 && tlx <= 4'd10) begin
                    // Head
                    vga_r = 4'hD; vga_g = 4'hB; vga_b = 4'h9;
                    // Glasses
                    if (tly >= 5'd2 && tly <= 5'd3) begin
                        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                    end
                end else if (tly >= 5'd5 && tly <= 5'd16 && tlx >= 4'd4 && tlx <= 4'd11) begin
                    // Dark green coat
                    vga_r = 4'h0; vga_g = 4'h3; vga_b = 4'h1;
                end else if (tly >= 5'd7 && tly <= 5'd15 && (tlx <= 4'd3 || tlx >= 4'd12)) begin
                    // Arms
                    vga_r = 4'h0; vga_g = 4'h2; vga_b = 4'h1;
                end else if (tly >= 5'd17 && ((tlx >= 4'd2 && tlx <= 4'd5) || (tlx >= 4'd10 && tlx <= 4'd13))) begin
                    // Feet
                    vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                end
                // Green highlight border (Trinity marker)
                if (tlx == 4'd0 || tlx == 4'd15 || tly == 5'd0 || tly == 5'd19) begin
                    vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'h6;
                end
            end

            // Layer 5: Smiths - detailed person sprite
            if (smith_on) begin
                if (smith_ly < 5'd5 && smith_lx >= 4'd5 && smith_lx <= 4'd10) begin
                    // Head (skin)
                    vga_r = 4'hD; vga_g = 4'hC; vga_b = 4'h9;
                    // Glasses (black bar)
                    if (smith_ly >= 5'd2 && smith_ly <= 5'd3) begin
                        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                    end
                end else if (smith_ly >= 5'd5 && smith_ly <= 5'd16 && smith_lx >= 4'd4 && smith_lx <= 4'd11) begin
                    // Body (suit)
                    if (smith_is_stunned) begin
                        vga_r = 4'h2; vga_g = 4'h5; vga_b = 4'h6;
                    end else if (smith_is_chasing) begin
                        vga_r = 4'h3; vga_g = 4'h0; vga_b = 4'h0;
                    end else begin
                        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                    end
                    // Tie (white/silver center stripe)
                    if (smith_lx >= 4'd7 && smith_lx <= 4'd8) begin
                        vga_r = 4'hC; vga_g = 4'hC; vga_b = 4'hC;
                    end
                end else if (smith_ly >= 5'd7 && smith_ly <= 5'd15 && (smith_lx <= 4'd3 || smith_lx >= 4'd12)) begin
                    // Arms
                    if (smith_is_stunned) begin
                        vga_r = 4'h1; vga_g = 4'h4; vga_b = 4'h5;
                    end else begin
                        vga_r = 4'h1; vga_g = 4'h1; vga_b = 4'h1;
                    end
                end else if (smith_ly >= 5'd17 && ((smith_lx >= 4'd2 && smith_lx <= 4'd5) || (smith_lx >= 4'd10 && smith_lx <= 4'd13))) begin
                    // Feet
                    vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                end
                // Chasing indicator border
                if (smith_is_chasing && (smith_lx == 4'd0 || smith_lx == 4'd15 || smith_ly == 5'd0 || smith_ly == 5'd19)) begin
                    vga_r = 4'hF; vga_g = 4'h2; vga_b = 4'h2;
                end
            end

            // Layer 6: Bombs & Bullets
            if (bomb_on) begin
                vga_r = bomb_flash ? 4'hF : 4'hF;
                vga_g = bomb_flash ? 4'hF : 4'h6;
                vga_b = bomb_flash ? 4'hB : 4'h1;
            end
            if (bullet_on) begin
                vga_r = 4'hE; vga_g = 4'hF; vga_b = 4'h7;
            end

            // Layer 7: Player (Neo)
            // Layer 7: Player (Neo) - detailed person sprite
            if (neo_on) begin
                if (neo_ly < 5'd5 && neo_lx >= 4'd5 && neo_lx <= 4'd10) begin
                    // Head (skin)
                    vga_r = 4'hD; vga_g = 4'hB; vga_b = 4'h8;
                    // Glasses
                    if (neo_ly >= 5'd2 && neo_ly <= 5'd3) begin
                        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                    end
                end else if (neo_ly >= 5'd5 && neo_ly <= 5'd16 && neo_lx >= 4'd4 && neo_lx <= 4'd11) begin
                    // Body (dark green coat)
                    vga_r = 4'h0; vga_g = 4'h2; vga_b = 4'h1;
                end else if (neo_ly >= 5'd7 && neo_ly <= 5'd15 && (neo_lx <= 4'd3 || neo_lx >= 4'd12)) begin
                    // Arms (coat)
                    vga_r = 4'h0; vga_g = 4'h1; vga_b = 4'h0;
                end else if (neo_ly >= 5'd17 && ((neo_lx >= 4'd2 && neo_lx <= 4'd5) || (neo_lx >= 4'd10 && neo_lx <= 4'd13))) begin
                    // Feet (black)
                    vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                end else begin
                    // Transparent (show background)
                    // keep current pixel color
                end
                // Cloak dither
                if (cloak_timer != 9'd0 && (pixel_x[0] ^ pixel_y[0])) begin
                    vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                end
            end

            // Post-processing: compass arrow overlay
            if (compass_pixel) begin
                vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
            end

            // Post-processing: bullet time grid
            if (bt_timer != 9'd0 && (pixel_x[4:0] == 5'd0 || pixel_y[4:0] == 5'd0)) begin
                vga_g = vga_g | 4'h6;
            end

            // Post-processing: attract flash
            if (attract_timer != 8'd0 && frame_count[3]) begin
                vga_r = vga_r ^ 4'h7;
                vga_g = vga_g >> 1;
                vga_b = vga_b >> 1;
            end

            // EMP visual
            if (emp_visual != 9'd0) begin
                if (pixel_x[3:0] == 4'd0 || pixel_y[3:0] == 4'd0) begin
                    vga_r = 4'h6; vga_g = 4'hF; vga_b = 4'hF;
                end
            end

            // Rain overlay
            if (rain_on) begin
                vga_g = vga_g | 4'h3;
            end

            // HUD bar with stats
            if (hud_on) begin
                vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                // Quest objective text
                if (text_hit) begin
                    vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
                end
                // Numeric stats display in HUD
                // Layout: A:xx  B:x  E:x  C:x  R:x/x
                // Starting at pixel_x = 360, pixel_y = 460..466 (7px tall digits)
                if (pixel_y >= 10'd460 && pixel_y < 10'd467) begin : hud_digits
                    reg [2:0] hud_row;
                    reg hud_pixel;
                    hud_row = pixel_y[2:0] - 3'd4; // row within digit

                    hud_pixel = 1'b0;

                    // "A:" at x=360
                    if (pixel_x >= 10'd360 && pixel_x < 10'd365)
                        hud_pixel = hud_char_pixel(5'd0, pixel_x[2:0] - 3'd0, hud_row); // A
                    // Ammo tens at x=368
                    if (pixel_x >= 10'd368 && pixel_x < 10'd373)
                        hud_pixel = hud_digit_pixel(ammo_tens, pixel_x - 10'd368, hud_row);
                    // Ammo ones at x=374
                    if (pixel_x >= 10'd374 && pixel_x < 10'd379)
                        hud_pixel = hud_digit_pixel(ammo_ones, pixel_x - 10'd374, hud_row);

                    // "B:" at x=390
                    if (pixel_x >= 10'd390 && pixel_x < 10'd395)
                        hud_pixel = hud_char_pixel(5'd1, pixel_x[2:0] - 3'd6, hud_row); // B
                    // Charges at x=398
                    if (pixel_x >= 10'd398 && pixel_x < 10'd403)
                        hud_pixel = hud_digit_pixel({1'b0, charges}, pixel_x - 10'd398, hud_row);

                    // "E:" at x=414
                    if (pixel_x >= 10'd414 && pixel_x < 10'd419)
                        hud_pixel = hud_char_pixel(5'd4, pixel_x[2:0] - 3'd6, hud_row); // E
                    // EMP count at x=422
                    if (pixel_x >= 10'd422 && pixel_x < 10'd427)
                        hud_pixel = hud_digit_pixel({2'b00, emp_count}, pixel_x - 10'd422, hud_row);

                    // "R:" at x=440
                    if (pixel_x >= 10'd440 && pixel_x < 10'd445)
                        hud_pixel = hud_char_pixel(5'd17, pixel_x[2:0] - 3'd0, hud_row); // R
                    // Rescued at x=448
                    if (pixel_x >= 10'd448 && pixel_x < 10'd453)
                        hud_pixel = hud_digit_pixel({1'b0, rescued}, pixel_x - 10'd448, hud_row);
                    // "/" at x=454 (simple slash pixel)
                    if (pixel_x == 10'd455 || pixel_x == 10'd456)
                        hud_pixel = (pixel_x[0] ^ pixel_y[0]);
                    // Goal at x=458
                    if (pixel_x >= 10'd458 && pixel_x < 10'd463)
                        hud_pixel = hud_digit_pixel({1'b0, rescue_goal}, pixel_x - 10'd458, hud_row);

                    if (hud_pixel) begin
                        vga_r = 4'hB; vga_g = 4'hF; vga_b = 4'hC;
                    end
                end
            end

            // Bullet time bar at top
            if (bt_bar_on) begin
                vga_r = 4'h5; vga_g = 4'hF; vga_b = 4'h7;
            end
        end
    end

    // Ammo digit split
    wire [3:0] ammo_tens = ammo / 6'd10;
    wire [3:0] ammo_ones = ammo % 6'd10;

    // HUD digit pixel lookup (5x7 font for 0-9)
    function hud_digit_pixel;
        input [3:0] digit;
        input [9:0] col;
        input [2:0] row;
        reg [4:0] bits;
        begin
            bits = 5'b00000;
            case (digit)
                4'd0: case(row) 3'd0:bits=5'b01110; 3'd1:bits=5'b10001; 3'd2:bits=5'b10011; 3'd3:bits=5'b10101; 3'd4:bits=5'b11001; 3'd5:bits=5'b10001; 3'd6:bits=5'b01110; default:bits=5'b00000; endcase
                4'd1: case(row) 3'd0:bits=5'b00100; 3'd1:bits=5'b01100; 3'd2:bits=5'b00100; 3'd3:bits=5'b00100; 3'd4:bits=5'b00100; 3'd5:bits=5'b00100; 3'd6:bits=5'b01110; default:bits=5'b00000; endcase
                4'd2: case(row) 3'd0:bits=5'b01110; 3'd1:bits=5'b10001; 3'd2:bits=5'b00001; 3'd3:bits=5'b00110; 3'd4:bits=5'b01000; 3'd5:bits=5'b10000; 3'd6:bits=5'b11111; default:bits=5'b00000; endcase
                4'd3: case(row) 3'd0:bits=5'b01110; 3'd1:bits=5'b10001; 3'd2:bits=5'b00001; 3'd3:bits=5'b00110; 3'd4:bits=5'b00001; 3'd5:bits=5'b10001; 3'd6:bits=5'b01110; default:bits=5'b00000; endcase
                4'd4: case(row) 3'd0:bits=5'b00010; 3'd1:bits=5'b00110; 3'd2:bits=5'b01010; 3'd3:bits=5'b10010; 3'd4:bits=5'b11111; 3'd5:bits=5'b00010; 3'd6:bits=5'b00010; default:bits=5'b00000; endcase
                4'd5: case(row) 3'd0:bits=5'b11111; 3'd1:bits=5'b10000; 3'd2:bits=5'b11110; 3'd3:bits=5'b00001; 3'd4:bits=5'b00001; 3'd5:bits=5'b10001; 3'd6:bits=5'b01110; default:bits=5'b00000; endcase
                4'd6: case(row) 3'd0:bits=5'b00110; 3'd1:bits=5'b01000; 3'd2:bits=5'b10000; 3'd3:bits=5'b11110; 3'd4:bits=5'b10001; 3'd5:bits=5'b10001; 3'd6:bits=5'b01110; default:bits=5'b00000; endcase
                4'd7: case(row) 3'd0:bits=5'b11111; 3'd1:bits=5'b00001; 3'd2:bits=5'b00010; 3'd3:bits=5'b00100; 3'd4:bits=5'b01000; 3'd5:bits=5'b01000; 3'd6:bits=5'b01000; default:bits=5'b00000; endcase
                4'd8: case(row) 3'd0:bits=5'b01110; 3'd1:bits=5'b10001; 3'd2:bits=5'b10001; 3'd3:bits=5'b01110; 3'd4:bits=5'b10001; 3'd5:bits=5'b10001; 3'd6:bits=5'b01110; default:bits=5'b00000; endcase
                4'd9: case(row) 3'd0:bits=5'b01110; 3'd1:bits=5'b10001; 3'd2:bits=5'b10001; 3'd3:bits=5'b01111; 3'd4:bits=5'b00001; 3'd5:bits=5'b00010; 3'd6:bits=5'b01100; default:bits=5'b00000; endcase
                default: bits = 5'b00000;
            endcase
            hud_digit_pixel = (col[2:0] < 3'd5) && bits[3'd4 - col[2:0]];
        end
    endfunction

    // HUD letter pixel lookup (reuse font for A,B,E,R labels)
    function hud_char_pixel;
        input [4:0] ch;
        input [2:0] col;
        input [2:0] row;
        reg [4:0] bits;
        begin
            bits = 5'b00000;
            case (ch)
                5'd0: case(row) 3'd0:bits=5'b01110; 3'd1:bits=5'b10001; 3'd2:bits=5'b10001; 3'd3:bits=5'b11111; 3'd4:bits=5'b10001; 3'd5:bits=5'b10001; 3'd6:bits=5'b10001; default:bits=5'b00000; endcase // A
                5'd1: case(row) 3'd0:bits=5'b11110; 3'd1:bits=5'b10001; 3'd2:bits=5'b10001; 3'd3:bits=5'b11110; 3'd4:bits=5'b10001; 3'd5:bits=5'b10001; 3'd6:bits=5'b11110; default:bits=5'b00000; endcase // B
                5'd4: case(row) 3'd0:bits=5'b11111; 3'd1:bits=5'b10000; 3'd2:bits=5'b10000; 3'd3:bits=5'b11110; 3'd4:bits=5'b10000; 3'd5:bits=5'b10000; 3'd6:bits=5'b11111; default:bits=5'b00000; endcase // E
                5'd17: case(row) 3'd0:bits=5'b11110; 3'd1:bits=5'b10001; 3'd2:bits=5'b10001; 3'd3:bits=5'b11110; 3'd4:bits=5'b10100; 3'd5:bits=5'b10010; 3'd6:bits=5'b10001; default:bits=5'b00000; endcase // R
                default: bits = 5'b00000;
            endcase
            hud_char_pixel = (col < 3'd5) && bits[3'd4 - col];
        end
    endfunction

endmodule
