module slot3_entities (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,
    input  wire        playing,
    input  wire [7:0]  move_phase,
    input  wire [31:0] lfsr,
    input  wire [3:0]  level,
    input  wire        bullet_time_active,
    input  wire [8:0]  cloak_timer,
    input  wire [9:0]  neo_x,
    input  wire [8:0]  neo_y,
    input  wire [1:0]  neo_dir,
    input  wire [3:0]  river_y,
    input  wire        start_level,
    input  wire [31:0] init_seed,
    input  wire [7:0]  smith_kill_mask,
    input  wire [7:0]  smith_stun_set,
    input  wire [7:0]  npc_rescue_mask,
    input  wire        replicate_en,
    input  wire [2:0]  replicate_npc_idx,
    output wire [9:0]  smith_x0, smith_x1, smith_x2, smith_x3,
    output wire [9:0]  smith_x4, smith_x5, smith_x6, smith_x7,
    output wire [8:0]  smith_y0, smith_y1, smith_y2, smith_y3,
    output wire [8:0]  smith_y4, smith_y5, smith_y6, smith_y7,
    output wire [1:0]  smith_type0, smith_type1, smith_type2, smith_type3,
    output wire [1:0]  smith_type4, smith_type5, smith_type6, smith_type7,
    output reg  [7:0]  smith_active,
    output wire [5:0]  smith_stun0, smith_stun1, smith_stun2, smith_stun3,
    output wire [5:0]  smith_stun4, smith_stun5, smith_stun6, smith_stun7,
    output wire [7:0]  smith_chasing,
    output wire [9:0]  npc_x0, npc_x1, npc_x2, npc_x3,
    output wire [9:0]  npc_x4, npc_x5, npc_x6, npc_x7,
    output wire [8:0]  npc_y0, npc_y1, npc_y2, npc_y3,
    output wire [8:0]  npc_y4, npc_y5, npc_y6, npc_y7,
    output reg  [7:0]  npc_alive,
    output reg  [9:0]  red_x,
    output reg  [8:0]  red_y,
    output reg  [9:0]  trinity_x,
    output reg  [8:0]  trinity_y
);

    localparam [9:0] WORLD_W = 10'd640;
    localparam [8:0] WORLD_H = 9'd480;
    localparam [9:0] SMITH_W = 10'd16;
    localparam [8:0] SMITH_H = 9'd20;
    localparam [9:0] NPC_W   = 10'd15;
    localparam [8:0] NPC_H   = 9'd19;

    reg [9:0] smith_x [0:7];
    reg [8:0] smith_y [0:7];
    reg [1:0] smith_type [0:7];
    reg [5:0] smith_stun [0:7];
    reg [9:0] npc_x [0:7];
    reg [8:0] npc_y [0:7];

    assign smith_x0=smith_x[0]; assign smith_x1=smith_x[1]; assign smith_x2=smith_x[2]; assign smith_x3=smith_x[3];
    assign smith_x4=smith_x[4]; assign smith_x5=smith_x[5]; assign smith_x6=smith_x[6]; assign smith_x7=smith_x[7];
    assign smith_y0=smith_y[0]; assign smith_y1=smith_y[1]; assign smith_y2=smith_y[2]; assign smith_y3=smith_y[3];
    assign smith_y4=smith_y[4]; assign smith_y5=smith_y[5]; assign smith_y6=smith_y[6]; assign smith_y7=smith_y[7];
    assign smith_type0=smith_type[0]; assign smith_type1=smith_type[1]; assign smith_type2=smith_type[2]; assign smith_type3=smith_type[3];
    assign smith_type4=smith_type[4]; assign smith_type5=smith_type[5]; assign smith_type6=smith_type[6]; assign smith_type7=smith_type[7];
    assign smith_stun0=smith_stun[0]; assign smith_stun1=smith_stun[1]; assign smith_stun2=smith_stun[2]; assign smith_stun3=smith_stun[3];
    assign smith_stun4=smith_stun[4]; assign smith_stun5=smith_stun[5]; assign smith_stun6=smith_stun[6]; assign smith_stun7=smith_stun[7];
    assign npc_x0=npc_x[0]; assign npc_x1=npc_x[1]; assign npc_x2=npc_x[2]; assign npc_x3=npc_x[3];
    assign npc_x4=npc_x[4]; assign npc_x5=npc_x[5]; assign npc_x6=npc_x[6]; assign npc_x7=npc_x[7];
    assign npc_y0=npc_y[0]; assign npc_y1=npc_y[1]; assign npc_y2=npc_y[2]; assign npc_y3=npc_y[3];
    assign npc_y4=npc_y[4]; assign npc_y5=npc_y[5]; assign npc_y6=npc_y[6]; assign npc_y7=npc_y[7];

    reg [5:0] smith_alert [0:7];
    reg [7:0] chase_reg;
    assign smith_chasing = chase_reg;

    wire npc_move_tick = frame_tick && (move_phase[3:0] == 4'b0000);
    wire smith_move_tick = frame_tick && (
        (bullet_time_active && (move_phase[4:0] == 5'b00000)) ||
        (!bullet_time_active && (move_phase[1:0] == 2'b00))
    );
    wire red_move_tick = frame_tick && (move_phase[4:0] == 5'b00000);
    wire trinity_move_tick = frame_tick && (move_phase[3:0] == 4'b0000);

    wire [10:0] detect_base = 11'd140 + {5'd0, level, 2'd0};
    wire [10:0] cloak_scale = (cloak_timer != 9'd0) ? 11'd70 : 11'd0;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1) begin
                smith_x[i] <= 10'd700;
                smith_y[i] <= 9'd500;
                smith_type[i] <= 2'd0;
                smith_alert[i] <= 6'd0;
                smith_stun[i] <= 6'd0;
                npc_x[i] <= 10'd80 + i[2:0] * 10'd60;
                npc_y[i] <= 9'd80 + i[2:0] * 9'd40;
            end
            smith_active <= 8'd0;
            npc_alive <= 8'd0;
            chase_reg <= 8'd0;
            red_x <= 10'd320; red_y <= 9'd200;
            trinity_x <= 10'd100; trinity_y <= 9'd80;
        end else if (start_level) begin
            smith_x[0] <= 10'd520; smith_y[0] <= 9'd360;
            smith_x[1] <= 10'd400; smith_y[1] <= 9'd80;
            smith_x[2] <= 10'd560; smith_y[2] <= 9'd200;
            for (i = 3; i < 8; i = i + 1) begin
                smith_x[i] <= 10'd700;
                smith_y[i] <= 9'd500;
            end
            smith_type[0] <= 2'd0;
            smith_type[1] <= 2'd1;
            smith_type[2] <= 2'd2;
            for (i = 3; i < 8; i = i + 1) smith_type[i] <= 2'd0;
            smith_active <= (level >= 4'd3) ? 8'b00000111 :
                           (level >= 4'd2) ? 8'b00000011 : 8'b00000001;
            for (i = 0; i < 8; i = i + 1) begin
                smith_alert[i] <= 6'd0;
                smith_stun[i] <= 6'd0;
            end
            npc_x[0] <= 10'd144; npc_y[0] <= 9'd320;
            npc_x[1] <= 10'd240; npc_y[1] <= 9'd96;
            npc_x[2] <= 10'd368; npc_y[2] <= 9'd256;
            npc_x[3] <= 10'd480; npc_y[3] <= 9'd160;
            npc_x[4] <= 10'd80;  npc_y[4] <= 9'd200;
            npc_x[5] <= 10'd544; npc_y[5] <= 9'd300;
            npc_x[6] <= 10'd288; npc_y[6] <= 9'd380;
            npc_x[7] <= 10'd416; npc_y[7] <= 9'd64;
            npc_alive <= 8'hFF;
            red_x <= 10'd300 + {6'd0, init_seed[3:0]};
            red_y <= 9'd180 + {5'd0, init_seed[7:4]};
            trinity_x <= 10'd100 + {5'd0, init_seed[12:8]};
            trinity_y <= 9'd64 + {5'd0, init_seed[16:13]};
            chase_reg <= 8'd0;
        end else begin
            // Smith kills from combat
            for (i = 0; i < 8; i = i + 1) begin
                if (smith_kill_mask[i]) begin
                    smith_x[i] <= 10'd700;
                    smith_y[i] <= 9'd500;
                    smith_active[i] <= 1'b0;
                end
            end

            // Smith stun from EMP
            for (i = 0; i < 8; i = i + 1) begin
                if (smith_stun_set[i]) smith_stun[i] <= 6'd50;
            end

            // NPC rescue
            for (i = 0; i < 8; i = i + 1) begin
                if (npc_rescue_mask[i]) npc_alive[i] <= 1'b0;
            end

            // Smith replication
            if (replicate_en) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (!smith_active[i]) begin
                        smith_x[i] <= npc_x[replicate_npc_idx];
                        smith_y[i] <= {1'b0, npc_y[replicate_npc_idx]};
                        smith_type[i] <= 2'd0;
                        smith_alert[i] <= 6'd0;
                        smith_stun[i] <= 6'd0;
                        smith_active[i] <= 1'b1;
                        // only activate one per frame - use disable
                    end
                end
            end

            if (frame_tick) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_stun[i] != 6'd0)
                        smith_stun[i] <= smith_stun[i] - 6'd1;
                end
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_alert[i] != 6'd0)
                        smith_alert[i] <= smith_alert[i] - 6'd1;
                end
            end

            // Smith AI movement - simplified for timing
            if (smith_move_tick && playing) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_active[i] && smith_stun[i] == 6'd0) begin
                        // Simple distance check: if both dx and dy < threshold, chase
                        if (((smith_x[i] > neo_x ? smith_x[i] - neo_x : neo_x - smith_x[i]) +
                             ({1'b0, smith_y[i]} > {1'b0, neo_y} ? {1'b0, smith_y[i]} - {1'b0, neo_y} : {1'b0, neo_y} - {1'b0, smith_y[i]})) < detect_base) begin
                            smith_alert[i] <= 6'd40;
                        end

                        chase_reg[i] <= (smith_alert[i] != 6'd0);

                        if (smith_alert[i] != 6'd0) begin
                            // Chase: move toward Neo, with river avoidance
                            if (smith_x[i] + 10'd5 < neo_x && smith_x[i] < WORLD_W - SMITH_W - 10'd2)
                                smith_x[i] <= smith_x[i] + 10'd1;
                            else if (smith_x[i] > neo_x + 10'd5 && smith_x[i] > 10'd2)
                                smith_x[i] <= smith_x[i] - 10'd1;

                            // Y movement with river check
                            if (smith_y[i] + 9'd5 < neo_y && smith_y[i] < WORLD_H - SMITH_H - 9'd2) begin
                                if (smith_y[i][8:5] + 4'd1 < river_y || smith_y[i][8:5] + 4'd1 >= river_y + 4'd3)
                                    smith_y[i] <= smith_y[i] + 9'd1;
                                else
                                    smith_x[i] <= (smith_x[i] < 10'd320) ? smith_x[i] + 10'd1 : smith_x[i] - 10'd1;
                            end else if (smith_y[i] > neo_y + 9'd5 && smith_y[i] > 9'd2) begin
                                if (smith_y[i][8:5] - 4'd1 < river_y || smith_y[i][8:5] - 4'd1 >= river_y + 4'd3)
                                    smith_y[i] <= smith_y[i] - 9'd1;
                                else
                                    smith_x[i] <= (smith_x[i] < 10'd320) ? smith_x[i] + 10'd1 : smith_x[i] - 10'd1;
                            end
                        end else begin
                            // Wander
                            if (lfsr[i])
                                smith_x[i] <= (smith_x[i] < WORLD_W - SMITH_W - 10'd2) ?
                                              smith_x[i] + 10'd1 : smith_x[i] - 10'd1;
                            else
                                smith_x[i] <= (smith_x[i] > 10'd2) ?
                                              smith_x[i] - 10'd1 : smith_x[i] + 10'd1;
                            if (lfsr[i + 8])
                                smith_y[i] <= (smith_y[i] < WORLD_H - SMITH_H - 9'd2) ?
                                              smith_y[i] + 9'd1 : smith_y[i] - 9'd1;
                            else
                                smith_y[i] <= (smith_y[i] > 9'd2) ?
                                              smith_y[i] - 9'd1 : smith_y[i] + 9'd1;
                        end
                    end
                end
            end

            // NPC movement
            if (npc_move_tick && playing) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (npc_alive[i]) begin
                        if (lfsr[i + 16])
                            npc_x[i] <= (npc_x[i] < WORLD_W - NPC_W - 10'd2) ?
                                        npc_x[i] + 10'd1 : npc_x[i] - 10'd1;
                        else
                            npc_x[i] <= (npc_x[i] > 10'd2) ?
                                        npc_x[i] - 10'd1 : npc_x[i] + 10'd1;
                        if (lfsr[i + 24])
                            npc_y[i] <= (npc_y[i] < WORLD_H - NPC_H - 9'd2) ?
                                        npc_y[i] + 9'd1 : npc_y[i] - 9'd1;
                        else
                            npc_y[i] <= (npc_y[i] > 9'd2) ?
                                        npc_y[i] - 9'd1 : npc_y[i] + 9'd1;
                    end
                end
            end

            // Red Woman movement
            if (red_move_tick && playing) begin
                if (lfsr[0]) red_x <= (red_x < WORLD_W - 10'd18) ? red_x + 10'd1 : red_x - 10'd1;
                else         red_x <= (red_x > 10'd2) ? red_x - 10'd1 : red_x + 10'd1;
                if (lfsr[1]) red_y <= (red_y < WORLD_H - 9'd22) ? red_y + 9'd1 : red_y - 9'd1;
                else         red_y <= (red_y > 9'd2) ? red_y - 9'd1 : red_y + 9'd1;
            end

            // Trinity movement
            if (trinity_move_tick && playing) begin
                if (lfsr[2]) trinity_x <= (trinity_x < WORLD_W - 10'd18) ? trinity_x + 10'd1 : trinity_x - 10'd1;
                else         trinity_x <= (trinity_x > 10'd2) ? trinity_x - 10'd1 : trinity_x + 10'd1;
                if (lfsr[3]) trinity_y <= (trinity_y < WORLD_H - 9'd22) ? trinity_y + 9'd1 : trinity_y - 9'd1;
                else         trinity_y <= (trinity_y > 9'd2) ? trinity_y - 9'd1 : trinity_y + 9'd1;
            end
        end
    end

endmodule
