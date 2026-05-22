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

    localparam [1:0] QUEST_TRINITY  = 2'd0;
    localparam [1:0] QUEST_TERMINAL = 2'd1;
    localparam [1:0] QUEST_RESCUE   = 2'd2;
    localparam [1:0] QUEST_PHONE    = 2'd3;

    localparam [2:0] PTYPE_GUN       = 3'd0;
    localparam [2:0] PTYPE_AMMO      = 3'd1;
    localparam [2:0] PTYPE_CHARGE    = 3'd2;
    localparam [2:0] PTYPE_EMP       = 3'd3;
    localparam [2:0] PTYPE_CLOAK     = 3'd4;
    localparam [2:0] PTYPE_MAP       = 3'd5;
    localparam [2:0] PTYPE_PHONECARD = 3'd6;

    reg [9:0] pickup_x [0:7];
    reg [8:0] pickup_y [0:7];
    reg [2:0] pickup_type [0:7];

    assign pickup_x0=pickup_x[0]; assign pickup_x1=pickup_x[1]; assign pickup_x2=pickup_x[2]; assign pickup_x3=pickup_x[3];
    assign pickup_x4=pickup_x[4]; assign pickup_x5=pickup_x[5]; assign pickup_x6=pickup_x[6]; assign pickup_x7=pickup_x[7];
    assign pickup_y0=pickup_y[0]; assign pickup_y1=pickup_y[1]; assign pickup_y2=pickup_y[2]; assign pickup_y3=pickup_y[3];
    assign pickup_y4=pickup_y[4]; assign pickup_y5=pickup_y[5]; assign pickup_y6=pickup_y[6]; assign pickup_y7=pickup_y[7];
    assign pickup_type0=pickup_type[0]; assign pickup_type1=pickup_type[1]; assign pickup_type2=pickup_type[2]; assign pickup_type3=pickup_type[3];
    assign pickup_type4=pickup_type[4]; assign pickup_type5=pickup_type[5]; assign pickup_type6=pickup_type[6]; assign pickup_type7=pickup_type[7];

    localparam [9:0] NEO_W = 10'd16;
    localparam [8:0] NEO_H = 9'd20;
    localparam [9:0] TRINITY_W = 10'd16;
    localparam [8:0] TRINITY_H = 9'd20;
    localparam [9:0] TERMINAL_W = 10'd24;
    localparam [8:0] TERMINAL_H = 9'd24;
    localparam [9:0] PHONE_W = 10'd32;
    localparam [8:0] PHONE_H = 9'd46;
    localparam [9:0] PICKUP_S = 10'd18;

    function overlap;
        input [9:0] ax, bx, aw, bw;
        input [8:0] ay, by, ah, bh;
        begin
            overlap = (ax < bx + bw) && (ax + aw > bx) &&
                      (ay < by + bh) && (ay + ah > by);
        end
    endfunction

    assign neo_touch_trinity = overlap(neo_x, trinity_x, NEO_W, TRINITY_W,
                                       neo_y, trinity_y, NEO_H, TRINITY_H);
    assign neo_touch_terminal = overlap(neo_x, terminal_x, NEO_W, TERMINAL_W,
                                        neo_y, terminal_y, NEO_H, TERMINAL_H);
    assign neo_touch_phone = overlap(neo_x, phone_x, NEO_W, PHONE_W,
                                     neo_y, phone_y, NEO_H, PHONE_H);
    assign phone_reachable = trinity_found && terminal_hacked && (rescued >= rescue_goal);

    integer i;

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
            rescue_goal <= 3'd3;
            phone_x <= 10'd576; phone_y <= 9'd32;
            terminal_x <= 10'd300; terminal_y <= 9'd200;
            pickup_active <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                pickup_x[i] <= 10'd0;
                pickup_y[i] <= 9'd0;
                pickup_type[i] <= 3'd0;
            end
        end else if (start_level) begin
            quest_phase <= QUEST_TRINITY;
            trinity_found <= 1'b0;
            terminal_hacked <= 1'b0;
            rescue_goal <= (level < 4'd3) ? 3'd2 : (level < 4'd5) ? 3'd3 : 3'd4;
            phone_x <= 10'd576; phone_y <= 9'd32;
            terminal_x <= 10'd192 + {4'd0, lfsr[5:0]};
            terminal_y <= 9'd160 + {4'd0, lfsr[10:6]};

            pickup_x[0] <= 10'd200 + {4'd0, lfsr[15:10]};
            pickup_y[0] <= 9'd120 + {4'd0, lfsr[20:16]};
            pickup_type[0] <= PTYPE_GUN;

            pickup_x[1] <= 10'd350 + {4'd0, lfsr[25:20]};
            pickup_y[1] <= 9'd280 + {5'd0, lfsr[28:25]};
            pickup_type[1] <= PTYPE_AMMO;

            pickup_x[2] <= 10'd100 + {4'd0, lfsr[5:0]};
            pickup_y[2] <= 9'd300 + {5'd0, lfsr[9:6]};
            pickup_type[2] <= PTYPE_CHARGE;

            pickup_x[3] <= 10'd450 + {5'd0, lfsr[14:10]};
            pickup_y[3] <= 9'd100 + {4'd0, lfsr[19:14]};
            pickup_type[3] <= PTYPE_CHARGE;

            pickup_x[4] <= 10'd280 + {4'd0, lfsr[24:19]};
            pickup_y[4] <= 9'd350 + {5'd0, lfsr[28:25]};
            pickup_type[4] <= PTYPE_EMP;

            pickup_x[5] <= 10'd500 + {5'd0, lfsr[4:0]};
            pickup_y[5] <= 9'd200 + {4'd0, lfsr[9:4]};
            pickup_type[5] <= PTYPE_CLOAK;

            pickup_x[6] <= 10'd150 + {4'd0, lfsr[15:10]};
            pickup_y[6] <= 9'd80 + {4'd0, lfsr[20:15]};
            pickup_type[6] <= PTYPE_MAP;

            pickup_x[7] <= 10'd400 + {4'd0, lfsr[25:20]};
            pickup_y[7] <= 9'd380 + {5'd0, lfsr[29:26]};
            pickup_type[7] <= PTYPE_PHONECARD;

            pickup_active <= 8'hFF;
        end else if (playing) begin
            // Quest progression
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

            // Pickup collection
            for (i = 0; i < 8; i = i + 1) begin
                if (neo_touch_pickup[i]) begin
                    pickup_active[i] <= 1'b0;
                end
            end
        end
    end

endmodule
