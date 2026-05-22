module slot3_combat (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,
    input  wire        playing,
    input  wire [7:0]  move_phase,
    input  wire        shoot_pulse,
    input  wire        bomb_pulse,
    input  wire        emp_pulse,
    input  wire [9:0]  neo_x,
    input  wire [8:0]  neo_y,
    input  wire [1:0]  neo_dir,
    input  wire [5:0]  ammo,
    input  wire [2:0]  charges,
    input  wire [1:0]  emp_count,
    input  wire        bullet_time_active,
    input  wire [9:0]  smith_x0, smith_x1, smith_x2, smith_x3,
    input  wire [9:0]  smith_x4, smith_x5, smith_x6, smith_x7,
    input  wire [8:0]  smith_y0, smith_y1, smith_y2, smith_y3,
    input  wire [8:0]  smith_y4, smith_y5, smith_y6, smith_y7,
    input  wire [7:0]  smith_active,
    input  wire [9:0]  npc_x0, npc_x1, npc_x2, npc_x3,
    input  wire [9:0]  npc_x4, npc_x5, npc_x6, npc_x7,
    input  wire [8:0]  npc_y0, npc_y1, npc_y2, npc_y3,
    input  wire [8:0]  npc_y4, npc_y5, npc_y6, npc_y7,
    input  wire [7:0]  npc_alive,
    input  wire [7:0]  smith_chasing,
    output reg         use_ammo,
    output reg         use_charge,
    output reg         use_emp,
    output reg  [7:0]  smith_kill_mask,
    output reg  [7:0]  smith_stun_mask,
    output reg         replicate_en,
    output reg  [2:0]  replicate_npc_idx,
    output wire [9:0]  bullet_x0, bullet_x1, bullet_x2, bullet_x3,
    output wire [8:0]  bullet_y0, bullet_y1, bullet_y2, bullet_y3,
    output wire [1:0]  bullet_dir0, bullet_dir1, bullet_dir2, bullet_dir3,
    output reg  [3:0]  bullet_active,
    output wire [9:0]  bomb_x0, bomb_x1, bomb_x2, bomb_x3,
    output wire [8:0]  bomb_y0, bomb_y1, bomb_y2, bomb_y3,
    output wire [7:0]  bomb_timer0, bomb_timer1, bomb_timer2, bomb_timer3,
    output reg  [3:0]  bomb_active,
    output reg         destroy_en,
    output reg  [4:0]  destroy_tx,
    output reg  [3:0]  destroy_ty,
    output reg  [8:0]  emp_visual,
    input  wire        start_level
);

    reg [9:0] bullet_x [0:3];
    reg [8:0] bullet_y [0:3];
    reg [1:0] bullet_dir [0:3];
    reg [9:0] bomb_x [0:3];
    reg [8:0] bomb_y [0:3];
    reg [7:0] bomb_timer [0:3];

    assign bullet_x0=bullet_x[0]; assign bullet_x1=bullet_x[1]; assign bullet_x2=bullet_x[2]; assign bullet_x3=bullet_x[3];
    assign bullet_y0=bullet_y[0]; assign bullet_y1=bullet_y[1]; assign bullet_y2=bullet_y[2]; assign bullet_y3=bullet_y[3];
    assign bullet_dir0=bullet_dir[0]; assign bullet_dir1=bullet_dir[1]; assign bullet_dir2=bullet_dir[2]; assign bullet_dir3=bullet_dir[3];
    assign bomb_x0=bomb_x[0]; assign bomb_x1=bomb_x[1]; assign bomb_x2=bomb_x[2]; assign bomb_x3=bomb_x[3];
    assign bomb_y0=bomb_y[0]; assign bomb_y1=bomb_y[1]; assign bomb_y2=bomb_y[2]; assign bomb_y3=bomb_y[3];
    assign bomb_timer0=bomb_timer[0]; assign bomb_timer1=bomb_timer[1]; assign bomb_timer2=bomb_timer[2]; assign bomb_timer3=bomb_timer[3];

    localparam [9:0] BULLET_SPEED = 10'd6;
    localparam [7:0] BOMB_FUSE    = 8'd110;
    localparam [9:0] SMITH_W      = 10'd16;
    localparam [8:0] SMITH_H      = 9'd20;
    localparam [9:0] NPC_W        = 10'd15;
    localparam [8:0] NPC_H        = 9'd19;

    wire bullet_move_tick = frame_tick && (move_phase[0] == 1'b0);
    reg [3:0] shoot_cooldown;
    reg [3:0] bomb_cooldown;

    // Smith position arrays for indexing
    wire [9:0] sx [0:7];
    wire [8:0] sy [0:7];
    assign sx[0]=smith_x0; assign sx[1]=smith_x1; assign sx[2]=smith_x2; assign sx[3]=smith_x3;
    assign sx[4]=smith_x4; assign sx[5]=smith_x5; assign sx[6]=smith_x6; assign sx[7]=smith_x7;
    assign sy[0]=smith_y0; assign sy[1]=smith_y1; assign sy[2]=smith_y2; assign sy[3]=smith_y3;
    assign sy[4]=smith_y4; assign sy[5]=smith_y5; assign sy[6]=smith_y6; assign sy[7]=smith_y7;

    wire [9:0] nx [0:7];
    wire [8:0] ny [0:7];
    assign nx[0]=npc_x0; assign nx[1]=npc_x1; assign nx[2]=npc_x2; assign nx[3]=npc_x3;
    assign nx[4]=npc_x4; assign nx[5]=npc_x5; assign nx[6]=npc_x6; assign nx[7]=npc_x7;
    assign ny[0]=npc_y0; assign ny[1]=npc_y1; assign ny[2]=npc_y2; assign ny[3]=npc_y3;
    assign ny[4]=npc_y4; assign ny[5]=npc_y5; assign ny[6]=npc_y6; assign ny[7]=npc_y7;

    reg [9:0] sx_q [0:7];
    reg [8:0] sy_q [0:7];
    reg [9:0] nx_q [0:7];
    reg [8:0] ny_q [0:7];
    reg [7:0] smith_active_q;
    reg [7:0] npc_alive_q;
    reg [2:0] replicate_scan_smith;
    reg [2:0] replicate_scan_npc;

    integer i, j;

    always @(posedge clk) begin
        if (reset || start_level) begin
            for (i = 0; i < 4; i = i + 1) begin
                bullet_x[i] <= 10'd0;
                bullet_y[i] <= 9'd0;
                bullet_dir[i] <= 2'd0;
                bomb_x[i] <= 10'd0;
                bomb_y[i] <= 9'd0;
                bomb_timer[i] <= 8'd0;
            end
            bullet_active <= 4'd0;
            bomb_active <= 4'd0;
            shoot_cooldown <= 4'd0;
            bomb_cooldown <= 4'd0;
            emp_visual <= 9'd0;
            use_ammo <= 1'b0;
            use_charge <= 1'b0;
            use_emp <= 1'b0;
            smith_kill_mask <= 8'd0;
            smith_stun_mask <= 8'd0;
            destroy_en <= 1'b0;
            replicate_en <= 1'b0;
            replicate_npc_idx <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                sx_q[i] <= 10'd0;
                sy_q[i] <= 9'd0;
                nx_q[i] <= 10'd0;
                ny_q[i] <= 9'd0;
            end
            smith_active_q <= 8'd0;
            npc_alive_q <= 8'd0;
            replicate_scan_smith <= 3'd0;
            replicate_scan_npc <= 3'd0;
        end else begin
            for (i = 0; i < 8; i = i + 1) begin
                sx_q[i] <= sx[i];
                sy_q[i] <= sy[i];
                nx_q[i] <= nx[i];
                ny_q[i] <= ny[i];
            end
            smith_active_q <= smith_active;
            npc_alive_q <= npc_alive;

            use_ammo <= 1'b0;
            use_charge <= 1'b0;
            use_emp <= 1'b0;
            smith_kill_mask <= 8'd0;
            smith_stun_mask <= 8'd0;
            destroy_en <= 1'b0;
            replicate_en <= 1'b0;

            if (frame_tick) begin
                if (shoot_cooldown != 4'd0) shoot_cooldown <= shoot_cooldown - 4'd1;
                if (bomb_cooldown != 4'd0) bomb_cooldown <= bomb_cooldown - 4'd1;
                if (emp_visual != 9'd0) emp_visual <= emp_visual - 9'd1;
            end

            // Find free bullet/bomb slot (priority encoder)
            begin : find_free
                reg [1:0] free_bullet;
                reg       has_free_bullet;
                reg [1:0] free_bomb;
                reg       has_free_bomb;
                has_free_bullet = 1'b0;
                free_bullet = 2'd0;
                has_free_bomb = 1'b0;
                free_bomb = 2'd0;
                if (!bullet_active[0])      begin free_bullet = 2'd0; has_free_bullet = 1'b1; end
                else if (!bullet_active[1]) begin free_bullet = 2'd1; has_free_bullet = 1'b1; end
                else if (!bullet_active[2]) begin free_bullet = 2'd2; has_free_bullet = 1'b1; end
                else if (!bullet_active[3]) begin free_bullet = 2'd3; has_free_bullet = 1'b1; end
                if (!bomb_active[0])      begin free_bomb = 2'd0; has_free_bomb = 1'b1; end
                else if (!bomb_active[1]) begin free_bomb = 2'd1; has_free_bomb = 1'b1; end
                else if (!bomb_active[2]) begin free_bomb = 2'd2; has_free_bomb = 1'b1; end
                else if (!bomb_active[3]) begin free_bomb = 2'd3; has_free_bomb = 1'b1; end

                // Shoot
                if (shoot_pulse && playing && ammo != 6'd0 && shoot_cooldown == 4'd0 && has_free_bullet) begin
                    case (free_bullet)
                        2'd0: begin bullet_x[0] <= neo_x + 10'd8; bullet_y[0] <= neo_y[8:0] + 9'd10; bullet_dir[0] <= neo_dir; end
                        2'd1: begin bullet_x[1] <= neo_x + 10'd8; bullet_y[1] <= neo_y[8:0] + 9'd10; bullet_dir[1] <= neo_dir; end
                        2'd2: begin bullet_x[2] <= neo_x + 10'd8; bullet_y[2] <= neo_y[8:0] + 9'd10; bullet_dir[2] <= neo_dir; end
                        2'd3: begin bullet_x[3] <= neo_x + 10'd8; bullet_y[3] <= neo_y[8:0] + 9'd10; bullet_dir[3] <= neo_dir; end
                    endcase
                    bullet_active[free_bullet] <= 1'b1;
                    use_ammo <= 1'b1;
                    shoot_cooldown <= 4'd12;
                end

                // Bomb
                if (bomb_pulse && playing && charges != 3'd0 && bomb_cooldown == 4'd0 && has_free_bomb) begin
                    case (free_bomb)
                        2'd0: begin
                            case (neo_dir)
                                2'd0: begin bomb_x[0] <= neo_x; bomb_y[0] <= (neo_y > 9'd24) ? neo_y - 9'd24 : 9'd0; end
                                2'd1: begin bomb_x[0] <= neo_x + 10'd24; bomb_y[0] <= neo_y; end
                                2'd2: begin bomb_x[0] <= neo_x; bomb_y[0] <= neo_y + 9'd24; end
                                2'd3: begin bomb_x[0] <= (neo_x > 10'd24) ? neo_x - 10'd24 : 10'd0; bomb_y[0] <= neo_y; end
                            endcase
                            bomb_timer[0] <= BOMB_FUSE;
                        end
                        2'd1: begin
                            case (neo_dir)
                                2'd0: begin bomb_x[1] <= neo_x; bomb_y[1] <= (neo_y > 9'd24) ? neo_y - 9'd24 : 9'd0; end
                                2'd1: begin bomb_x[1] <= neo_x + 10'd24; bomb_y[1] <= neo_y; end
                                2'd2: begin bomb_x[1] <= neo_x; bomb_y[1] <= neo_y + 9'd24; end
                                2'd3: begin bomb_x[1] <= (neo_x > 10'd24) ? neo_x - 10'd24 : 10'd0; bomb_y[1] <= neo_y; end
                            endcase
                            bomb_timer[1] <= BOMB_FUSE;
                        end
                        2'd2: begin
                            case (neo_dir)
                                2'd0: begin bomb_x[2] <= neo_x; bomb_y[2] <= (neo_y > 9'd24) ? neo_y - 9'd24 : 9'd0; end
                                2'd1: begin bomb_x[2] <= neo_x + 10'd24; bomb_y[2] <= neo_y; end
                                2'd2: begin bomb_x[2] <= neo_x; bomb_y[2] <= neo_y + 9'd24; end
                                2'd3: begin bomb_x[2] <= (neo_x > 10'd24) ? neo_x - 10'd24 : 10'd0; bomb_y[2] <= neo_y; end
                            endcase
                            bomb_timer[2] <= BOMB_FUSE;
                        end
                        2'd3: begin
                            case (neo_dir)
                                2'd0: begin bomb_x[3] <= neo_x; bomb_y[3] <= (neo_y > 9'd24) ? neo_y - 9'd24 : 9'd0; end
                                2'd1: begin bomb_x[3] <= neo_x + 10'd24; bomb_y[3] <= neo_y; end
                                2'd2: begin bomb_x[3] <= neo_x; bomb_y[3] <= neo_y + 9'd24; end
                                2'd3: begin bomb_x[3] <= (neo_x > 10'd24) ? neo_x - 10'd24 : 10'd0; bomb_y[3] <= neo_y; end
                            endcase
                            bomb_timer[3] <= BOMB_FUSE;
                        end
                    endcase
                    bomb_active[free_bomb] <= 1'b1;
                    use_charge <= 1'b1;
                    bomb_cooldown <= 4'd12;
                end
            end

            // EMP
            if (emp_pulse && playing && emp_count != 2'd0) begin
                use_emp <= 1'b1;
                emp_visual <= 9'd150;
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_active_q[i]) begin : emp_dist
                        reg [10:0] dx, dy;
                        dx = (sx_q[i] > neo_x) ? (sx_q[i] - neo_x) : (neo_x - sx_q[i]);
                        dy = (sy_q[i] > neo_y) ? ({2'd0, sy_q[i]} - {2'd0, neo_y}) :
                                                 ({2'd0, neo_y} - {2'd0, sy_q[i]});
                        if (dx + dy < 11'd190)
                            smith_stun_mask[i] <= 1'b1;
                    end
                end
            end

            // Bullet movement & collision
            if (bullet_move_tick && playing) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (bullet_active[i]) begin
                        case (bullet_dir[i])
                            2'd0: bullet_y[i] <= bullet_y[i] - BULLET_SPEED[8:0];
                            2'd1: bullet_x[i] <= bullet_x[i] + BULLET_SPEED;
                            2'd2: bullet_y[i] <= bullet_y[i] + BULLET_SPEED[8:0];
                            2'd3: bullet_x[i] <= bullet_x[i] - BULLET_SPEED;
                        endcase

                        // Out of bounds
                        if (bullet_x[i] < 10'd4 || bullet_x[i] > 10'd632 ||
                            bullet_y[i] < 9'd4 || bullet_y[i] > 9'd472) begin
                            bullet_active[i] <= 1'b0;
                        end

                        // Hit smith
                        for (j = 0; j < 8; j = j + 1) begin
                            if (smith_active_q[j] &&
                                bullet_x[i] + 10'd6 > sx_q[j] && bullet_x[i] < sx_q[j] + SMITH_W &&
                                {1'b0, bullet_y[i]} + 10'd6 > {1'b0, sy_q[j]} &&
                                {1'b0, bullet_y[i]} < {1'b0, sy_q[j]} + {1'b0, SMITH_H}) begin
                                smith_kill_mask[j] <= 1'b1;
                                bullet_active[i] <= 1'b0;
                            end
                        end
                    end
                end
            end

            // Bomb countdown & detonation
            if (frame_tick && playing) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (bomb_active[i]) begin
                        if (bomb_timer[i] == 8'd1) begin
                            bomb_active[i] <= 1'b0;
                            destroy_en <= 1'b1;
                            destroy_tx <= bomb_x[i][9:5];
                            destroy_ty <= bomb_y[i][8:5];
                            // Kill smiths in blast radius
                            for (j = 0; j < 8; j = j + 1) begin
                                if (smith_active_q[j]) begin : bomb_blast
                                    reg [10:0] bdx, bdy;
                                    bdx = (sx_q[j] > bomb_x[i]) ? (sx_q[j] - bomb_x[i]) : (bomb_x[i] - sx_q[j]);
                                    bdy = (sy_q[j] > bomb_y[i]) ? ({2'd0, sy_q[j]} - {2'd0, bomb_y[i]}) :
                                                                 ({2'd0, bomb_y[i]} - {2'd0, sy_q[j]});
                                    if (bdx + bdy < 11'd54)
                                        smith_kill_mask[j] <= 1'b1;
                                end
                            end
                        end else begin
                            bomb_timer[i] <= bomb_timer[i] - 8'd1;
                        end
                    end
                end
            end

            // Smith-NPC replication
            if (frame_tick && playing) begin
                if (smith_active_q[replicate_scan_smith] && npc_alive_q[replicate_scan_npc]) begin
                    if (sx_q[replicate_scan_smith] + SMITH_W > nx_q[replicate_scan_npc] &&
                        sx_q[replicate_scan_smith] < nx_q[replicate_scan_npc] + NPC_W &&
                        {1'b0, sy_q[replicate_scan_smith]} + {1'b0, SMITH_H} > {1'b0, ny_q[replicate_scan_npc]} &&
                        {1'b0, sy_q[replicate_scan_smith]} < {1'b0, ny_q[replicate_scan_npc]} + {1'b0, NPC_H}) begin
                        replicate_en <= 1'b1;
                        replicate_npc_idx <= replicate_scan_npc;
                    end
                end

                if (replicate_scan_npc == 3'd7) begin
                    replicate_scan_npc <= 3'd0;
                    replicate_scan_smith <= replicate_scan_smith + 3'd1;
                end else begin
                    replicate_scan_npc <= replicate_scan_npc + 3'd1;
                end
            end
        end
    end

endmodule
