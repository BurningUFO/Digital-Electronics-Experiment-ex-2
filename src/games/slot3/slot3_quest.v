// Quest and pickup logic for slot 3.
//
// The quest sequence is Trinity -> terminal -> rescue NPCs -> reachable phone.
// This module owns quest flags, pickup positions/types, and collision/touch
// outputs used by the top-level and player inventory.
module slot3_quest (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,
    input  wire        playing,
    input  wire [9:0]  neo_x,
    input  wire [8:0]  neo_y,
    input  wire [9:0]  trinity_x,
    input  wire [8:0]  trinity_y,
    input  wire [31:0] lfsr,
    input  wire        start_level,
    input  wire [3:0]  level,
    input  wire [2:0]  rescued,
    output reg  [1:0]  quest_phase,
    output reg         trinity_found,
    output reg         terminal_hacked,
    output reg  [2:0]  rescue_goal,
    output reg  [9:0]  phone_x,
    output reg  [8:0]  phone_y,
    output reg  [9:0]  terminal_x,
    output reg  [8:0]  terminal_y,
    output wire [9:0]  pickup_x0, pickup_x1, pickup_x2, pickup_x3,
    output wire [9:0]  pickup_x4, pickup_x5, pickup_x6, pickup_x7,
    output wire [8:0]  pickup_y0, pickup_y1, pickup_y2, pickup_y3,
    output wire [8:0]  pickup_y4, pickup_y5, pickup_y6, pickup_y7,
    output wire [2:0]  pickup_type0, pickup_type1, pickup_type2, pickup_type3,
    output wire [2:0]  pickup_type4, pickup_type5, pickup_type6, pickup_type7,
    output reg  [7:0]  pickup_active,
    output wire        neo_touch_trinity,
    output wire        neo_touch_terminal,
    output wire        neo_touch_phone,
    output reg  [7:0]  neo_touch_pickup,
    output wire        phone_reachable
);

    // Quest phase identifiers and pickup type encoding.
    localparam [1:0] QUEST_TRINITY  = 2'd0;
    localparam [1:0] QUEST_TERMINAL = 2'd1;
    localparam [1:0] QUEST_RESCUE   = 2'd2;
    localparam [1:0] QUEST_PHONE    = 2'd3;
    localparam [2:0] PTYPE_AMMO     = 3'd1;
    localparam [2:0] PTYPE_CHARGE   = 3'd2;
    localparam [2:0] PTYPE_EMP      = 3'd3;

    reg [9:0] pickup_x [0:7];
    reg [8:0] pickup_y [0:7];
    reg [2:0] pickup_type [0:7];

    // Flatten pickup arrays for Verilog-2001 style module ports.
    assign pickup_x0=pickup_x[0]; assign pickup_x1=pickup_x[1]; assign pickup_x2=pickup_x[2]; assign pickup_x3=pickup_x[3];
    assign pickup_x4=pickup_x[4]; assign pickup_x5=pickup_x[5]; assign pickup_x6=pickup_x[6]; assign pickup_x7=pickup_x[7];
    assign pickup_y0=pickup_y[0]; assign pickup_y1=pickup_y[1]; assign pickup_y2=pickup_y[2]; assign pickup_y3=pickup_y[3];
    assign pickup_y4=pickup_y[4]; assign pickup_y5=pickup_y[5]; assign pickup_y6=pickup_y[6]; assign pickup_y7=pickup_y[7];
    assign pickup_type0=pickup_type[0]; assign pickup_type1=pickup_type[1]; assign pickup_type2=pickup_type[2]; assign pickup_type3=pickup_type[3];
    assign pickup_type4=pickup_type[4]; assign pickup_type5=pickup_type[5]; assign pickup_type6=pickup_type[6]; assign pickup_type7=pickup_type[7];

    localparam [9:0] NEO_W = 10'd16;
    localparam [8:0] NEO_H = 9'd20;
    localparam [9:0] ACTOR_W = 10'd16;
    localparam [8:0] ACTOR_H = 9'd20;
    localparam [9:0] TERMINAL_W = 10'd24;
    localparam [8:0] TERMINAL_H = 9'd24;
    localparam [9:0] PHONE_W = 10'd24;
    localparam [8:0] PHONE_H = 9'd36;
    localparam [9:0] PICKUP_S = 10'd14;

    // Axis-aligned rectangle overlap helper for actor/object touch checks.
    function overlap;
        input [9:0] ax, bx, aw, bw;
        input [8:0] ay, by, ah, bh;
        begin
            overlap = (ax < bx + bw) && (ax + aw > bx) &&
                      (ay < by + bh) && (ay + ah > by);
        end
    endfunction

    assign neo_touch_trinity = overlap(neo_x, trinity_x, NEO_W, ACTOR_W, neo_y, trinity_y, NEO_H, ACTOR_H);
    assign neo_touch_terminal = overlap(neo_x, terminal_x, NEO_W, TERMINAL_W, neo_y, terminal_y, NEO_H, TERMINAL_H);
    assign neo_touch_phone = overlap(neo_x, phone_x, NEO_W, PHONE_W, neo_y, phone_y, NEO_H, PHONE_H);
    assign phone_reachable = trinity_found && terminal_hacked && (rescued >= rescue_goal);

    integer i;
    // Touch mask for pickups.  The active mask is checked by the top-level when
    // deciding which resource to grant.
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            neo_touch_pickup[i] = pickup_active[i] &&
                overlap(neo_x, pickup_x[i], NEO_W, PICKUP_S,
                        neo_y, pickup_y[i], NEO_H, PICKUP_S[8:0]);
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            quest_phase <= QUEST_TRINITY;
            trinity_found <= 1'b0;
            terminal_hacked <= 1'b0;
            rescue_goal <= 3'd2;
            phone_x <= 10'd576;
            phone_y <= 9'd48;
            terminal_x <= 10'd304;
            terminal_y <= 9'd176;
            pickup_active <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                pickup_x[i] <= 10'd0;
                pickup_y[i] <= 9'd0;
                pickup_type[i] <= 3'd0;
            end
        end else if (start_level) begin
            // Reset quest targets and scatter pickups for the new level.
            quest_phase <= QUEST_TRINITY;
            trinity_found <= 1'b0;
            terminal_hacked <= 1'b0;
            rescue_goal <= (level >= 4'd4) ? 3'd3 : 3'd2;

            case (lfsr[1:0])
                2'd0: begin
                    terminal_x <= 10'd208; terminal_y <= 9'd144;
                    phone_x <= 10'd560; phone_y <= 9'd48;
                    pickup_x[0] <= 10'd112; pickup_y[0] <= 9'd96;
                    pickup_x[1] <= 10'd336; pickup_y[1] <= 9'd336;
                    pickup_x[2] <= 10'd496; pickup_y[2] <= 9'd208;
                end
                2'd1: begin
                    terminal_x <= 10'd432; terminal_y <= 9'd112;
                    phone_x <= 10'd80; phone_y <= 9'd64;
                    pickup_x[0] <= 10'd160; pickup_y[0] <= 9'd352;
                    pickup_x[1] <= 10'd272; pickup_y[1] <= 9'd176;
                    pickup_x[2] <= 10'd512; pickup_y[2] <= 9'd304;
                end
                2'd2: begin
                    terminal_x <= 10'd272; terminal_y <= 9'd304;
                    phone_x <= 10'd560; phone_y <= 9'd80;
                    pickup_x[0] <= 10'd96; pickup_y[0] <= 9'd192;
                    pickup_x[1] <= 10'd224; pickup_y[1] <= 9'd80;
                    pickup_x[2] <= 10'd464; pickup_y[2] <= 9'd352;
                end
                default: begin
                    terminal_x <= 10'd368; terminal_y <= 9'd240;
                    phone_x <= 10'd560; phone_y <= 9'd48;
                    pickup_x[0] <= 10'd144; pickup_y[0] <= 9'd128;
                    pickup_x[1] <= 10'd304; pickup_y[1] <= 9'd368;
                    pickup_x[2] <= 10'd496; pickup_y[2] <= 9'd176;
                end
            endcase

            pickup_y[3] <= 9'd0; pickup_y[4] <= 9'd0; pickup_y[5] <= 9'd0; pickup_y[6] <= 9'd0; pickup_y[7] <= 9'd0;
            pickup_x[3] <= 10'd0; pickup_x[4] <= 10'd0; pickup_x[5] <= 10'd0; pickup_x[6] <= 10'd0; pickup_x[7] <= 10'd0;

            pickup_type[0] <= PTYPE_AMMO;
            pickup_type[1] <= PTYPE_CHARGE;
            pickup_type[2] <= PTYPE_EMP;
            pickup_type[3] <= 3'd0;
            pickup_type[4] <= 3'd0;
            pickup_type[5] <= 3'd0;
            pickup_type[6] <= 3'd0;
            pickup_type[7] <= 3'd0;
            pickup_active <= 8'b00000111;
        end else if (playing) begin
            // Quest phase advances only while actively playing.
            if (!trinity_found && neo_touch_trinity) begin
                trinity_found <= 1'b1;
                quest_phase <= QUEST_TERMINAL;
            end
            if (trinity_found && !terminal_hacked && neo_touch_terminal) begin
                terminal_hacked <= 1'b1;
                quest_phase <= QUEST_RESCUE;
            end
            if (terminal_hacked && rescued >= rescue_goal) begin
                quest_phase <= QUEST_PHONE;
            end

            for (i = 0; i < 8; i = i + 1) begin
                if (neo_touch_pickup[i]) begin
                    pickup_active[i] <= 1'b0;
                end
            end
        end
    end

endmodule
