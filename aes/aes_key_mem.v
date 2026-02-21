//======================================================================
//
// aes_key_mem.v
// -------------
// The AES key memory including round key generator.
// Supports 128 and 256 bit keys.
//
//======================================================================

module aes_key_mem(
                   input wire            clk,
                   input wire            reset,

                   input wire [255 : 0]  key,
                   input wire            keylen,
                   input wire            init,

                   input wire [3 : 0]    round,
                   output wire [127 : 0] round_key,
                   output wire           ready,
                   
                   output wire [31 : 0]  sboxw,
                   input wire [31 : 0]   new_sboxw
                  );


  //----------------------------------------------------------------
  // Parameters.
  //----------------------------------------------------------------
  localparam AES_128_BIT_KEY = 1'h0;
  localparam AES_256_BIT_KEY = 1'h1;

  localparam AES_128_NUM_ROUNDS = 10;
  localparam AES_256_NUM_ROUNDS = 14;

  localparam CTRL_IDLE     = 3'h0;
  localparam CTRL_INIT     = 3'h1;
  localparam CTRL_GENERATE = 3'h2;
  localparam CTRL_DONE     = 3'h3;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [127 : 0] key_mem [0 : 14];
  reg [127 : 0] key_mem_new;
  reg           key_mem_we;

  reg [127 : 0] prev_key0_reg;
  reg [127 : 0] prev_key0_new;
  reg           prev_key0_we;

  reg [127 : 0] prev_key1_reg;
  reg [127 : 0] prev_key1_new;
  reg           prev_key1_we;

  reg [3 : 0]   round_ctr_reg;
  reg [3 : 0]   round_ctr_new;
  reg           round_ctr_rst;
  reg           round_ctr_inc;
  reg           round_ctr_we;

  reg [2 : 0]   key_mem_ctrl_reg;
  reg [2 : 0]   key_mem_ctrl_new;
  reg           key_mem_ctrl_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg [7 : 0]   rcon_reg;
  reg [7 : 0]   rcon_new;
  reg           rcon_we;
  reg           rcon_set;
  reg           rcon_next;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]  tmp_sboxw;
  reg [127 : 0] tmp_round_key;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready     = ready_reg;
  assign round_key = tmp_round_key;
  assign sboxw     = tmp_sboxw;


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or posedge reset)
    begin: reg_update
      integer i;

      if (reset)
        begin
          for (i = 0 ; i < 15 ; i = i + 1)
            key_mem [i] <= 128'h0;

          rcon_reg         <= 8'h0;
          ready_reg        <= 1'b0;
          prev_key0_reg    <= 128'h0;
          prev_key1_reg    <= 128'h0;
          round_ctr_reg    <= 4'h0;
          key_mem_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (key_mem_we)
            key_mem[round_ctr_reg] <= key_mem_new;

          if (prev_key0_we)
            prev_key0_reg <= prev_key0_new;

          if (prev_key1_we)
            prev_key1_reg <= prev_key1_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (rcon_we)
            rcon_reg <= rcon_new;

          if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;

          if (key_mem_ctrl_we)
            key_mem_ctrl_reg <= key_mem_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // key_mem_read
  //
  // Combinational read port for the key memory.
  //----------------------------------------------------------------
  always @*
    begin : key_mem_read
      tmp_round_key = key_mem[round];
    end // key_mem_read


  //----------------------------------------------------------------
  // round_key_gen
  //
  // The round key generator logic for AES-128 and AES-256.
  //----------------------------------------------------------------
  always @*
    begin: round_key_gen
      reg [31 : 0] w0, w1, w2, w3, w4, w5, w6, w7;
      reg [31 : 0] k0, k1, k2, k3;
      reg [31 : 0] rconw, rotstw, tw, trw;

      // Default assignments.
      key_mem_new  = 128'h0;
      key_mem_we   = 1'b0;
      prev_key0_new = 128'h0;
      prev_key0_we  = 1'b0;
      prev_key1_new = 128'h0;
      prev_key1_we  = 1'b0;

      k0 = 32'h0;
      k1 = 32'h0;
      k2 = 32'h0;
      k3 = 32'h0;

      rcon_set   = 1'b0;
      rcon_next  = 1'b0;

      // Extract words from the previous key.
      // For AES-256, read from key_mem to access w[i-8]
      if (keylen == AES_256_BIT_KEY && round_ctr_reg >= 2)
        begin
          // Read w[i-8] from previously stored round keys
          w0 = key_mem[round_ctr_reg - 2][127 : 096];
          w1 = key_mem[round_ctr_reg - 2][095 : 064];
          w2 = key_mem[round_ctr_reg - 2][063 : 032];
          w3 = key_mem[round_ctr_reg - 2][031 : 000];
        end
      else
        begin
          w0 = prev_key0_reg[127 : 096];
          w1 = prev_key0_reg[095 : 064];
          w2 = prev_key0_reg[063 : 032];
          w3 = prev_key0_reg[031 : 000];
        end

      w4 = prev_key1_reg[127 : 096];
      w5 = prev_key1_reg[095 : 064];
      w6 = prev_key1_reg[063 : 032];
      w7 = prev_key1_reg[031 : 000];

      // Rotate SubWord(w3) for key expansion
      rotstw = {new_sboxw[23 : 00], new_sboxw[31 : 24]};
      trw    = new_sboxw;

      // Create the round constant word
      rconw = {rcon_reg, 24'h0};

      // Generate key depending on key length and round
      if (keylen == AES_128_BIT_KEY)
        begin
          if (round_ctr_reg == 0)
            begin
              key_mem_new   = key[255 : 128];
              key_mem_we    = 1'b1;
              prev_key1_new = key[255 : 128];
              prev_key1_we  = 1'b1;
              rcon_set      = 1'b1;
            end
          else
            begin
              // Generate new key words for AES-128
              k0 = w4 ^ rotstw ^ rconw;
              k1 = k0 ^ w5;
              k2 = k1 ^ w6;
              k3 = k2 ^ w7;

              key_mem_new   = {k0, k1, k2, k3};
              key_mem_we    = 1'b1;
              prev_key1_new = {k0, k1, k2, k3};
              prev_key1_we  = 1'b1;
              rcon_next     = 1'b1;
            end
        end
      else
        begin
          if (round_ctr_reg == 0)
            begin
              // Store first half of key as round key 0
              key_mem_new   = key[255 : 128];
              key_mem_we    = 1'b1;
              prev_key0_new = key[127 : 000];
              prev_key0_we  = 1'b1;
              prev_key1_new = key[255 : 128];
              prev_key1_we  = 1'b1;
              rcon_set      = 1'b1;
            end
          else if (round_ctr_reg == 1)
            begin
              // Store second half of key as round key 1
              key_mem_new   = key[127 : 000];
              key_mem_we    = 1'b1;
              // Don't update prev_key registers or rcon
            end
          else
            begin
              if (round_ctr_reg[0] == 0)
                begin
                  // Even round (2, 4, 6...), use RotWord(SubWord()) + Rcon
                  k0 = w0 ^ rotstw ^ rconw;
                  k1 = k0 ^ w1;
                  k2 = k1 ^ w2;
                  k3 = k2 ^ w3;
                end
              else
                begin
                  // Odd round (3, 5, 7...), use SubWord() without rotation or Rcon
                  k0 = w0 ^ trw;
                  k1 = k0 ^ w1;
                  k2 = k1 ^ w2;
                  k3 = k2 ^ w3;
                end

              // Update key memory and previous keys
              key_mem_new   = {k0, k1, k2, k3};
              key_mem_we    = 1'b1;
              prev_key0_new = prev_key1_reg;
              prev_key0_we  = 1'b1;
              prev_key1_new = {k0, k1, k2, k3};
              prev_key1_we  = 1'b1;

              if (round_ctr_reg[0] == 0)
                rcon_next = 1'b1;
            end
        end
    end // round_key_gen


  //----------------------------------------------------------------
  // rcon_logic
  //
  // Caclulate rcon for the different steps.
  //----------------------------------------------------------------
  always @*
    begin : rcon_logic
      rcon_new = 8'h00;
      rcon_we  = 1'b0;

      if (rcon_set)
        begin
          rcon_new = 8'h01;
          rcon_we  = 1'b1;
        end

      if (rcon_next)
        begin
          rcon_new = {rcon_reg[6 : 0], 1'b0} ^ (8'h1b & {8{rcon_reg[7]}});
          rcon_we  = 1'b1;
        end
    end // rcon_logic


  //----------------------------------------------------------------
  // round_ctr
  //
  // The round counter with reset and increase logic.
  //----------------------------------------------------------------
  always @*
    begin : round_ctr
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'b0;

      if (round_ctr_rst)
        begin
          round_ctr_new = 4'h0;
          round_ctr_we  = 1'b1;
        end

      if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'b1;
          round_ctr_we  = 1'b1;
        end
    end // round_ctr


  //----------------------------------------------------------------
  // key_mem_ctrl
  //
  // The FSM that controls the round key generation.
  //----------------------------------------------------------------
  always @*
    begin: key_mem_ctrl
      reg [3 : 0] num_rounds;

      // Default assignments.
      ready_new        = 1'b0;
      ready_we         = 1'b0;
      round_ctr_rst    = 1'b0;
      round_ctr_inc    = 1'b0;
      key_mem_ctrl_new = CTRL_IDLE;
      key_mem_ctrl_we  = 1'b0;

      if (keylen == AES_128_BIT_KEY)
        num_rounds = AES_128_NUM_ROUNDS;
      else
        num_rounds = AES_256_NUM_ROUNDS;

      case(key_mem_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                ready_new        = 1'b0;
                ready_we         = 1'b1;
                key_mem_ctrl_new = CTRL_INIT;
                key_mem_ctrl_we  = 1'b1;
              end
          end

        CTRL_INIT:
          begin
            round_ctr_rst    = 1'b1;
            key_mem_ctrl_new = CTRL_GENERATE;
            key_mem_ctrl_we  = 1'b1;
          end

        CTRL_GENERATE:
          begin
            round_ctr_inc    = 1'b1;
            if (round_ctr_reg == num_rounds)
              begin
                key_mem_ctrl_new = CTRL_DONE;
                key_mem_ctrl_we  = 1'b1;
              end
          end

        CTRL_DONE:
          begin
            ready_new        = 1'b1;
            ready_we         = 1'b1;
            key_mem_ctrl_new = CTRL_IDLE;
            key_mem_ctrl_we  = 1'b1;
          end

        default:
          begin
          end
      endcase // case (key_mem_ctrl_reg)
    end // key_mem_ctrl


  //----------------------------------------------------------------
  // sbox_mux
  //
  // Controls which word to send to the S-box.
  //----------------------------------------------------------------
  always @*
    begin : sbox_mux
      if (keylen == AES_128_BIT_KEY)
        tmp_sboxw = prev_key1_reg[031 : 000];
      else
        begin
          // For AES-256:
          // Round 2 is special (first generation, uses w7 from original key)
          // All other rounds use most recent generated keys from prev_key1
          if (round_ctr_reg == 4'd2)
            tmp_sboxw = prev_key0_reg[031 : 000];
          else
            tmp_sboxw = prev_key1_reg[031 : 000];
        end
    end // sbox_mux

endmodule // aes_key_mem

//======================================================================
// EOF aes_key_mem.v
//======================================================================
