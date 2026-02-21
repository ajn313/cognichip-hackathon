//======================================================================
//
// aes_encipher_block.v
// --------------------
// The AES encipher block that performs encryption rounds.
// Implements SubBytes, ShiftRows, MixColumns, and AddRoundKey.
// Supports both AES-128 and AES-256.
//
//======================================================================

module aes_encipher_block(
                          input wire            clk,
                          input wire            reset_n,

                          input wire            next,
                          input wire            keylen,

                          output wire [3 : 0]   round,
                          input wire [127 : 0]  round_key,

                          output wire [31 : 0]  sboxw,
                          input wire [31 : 0]   new_sboxw,

                          input wire [127 : 0]  block,
                          output wire [127 : 0] new_block,
                          output wire           ready
                         );


  //----------------------------------------------------------------
  // Parameters.
  //----------------------------------------------------------------
  localparam AES_128_BIT_KEY = 1'h0;
  localparam AES_256_BIT_KEY = 1'h1;

  localparam AES_128_NUM_ROUNDS = 10;
  localparam AES_256_NUM_ROUNDS = 14;

  localparam NO_UPDATE    = 3'h0;
  localparam INIT_UPDATE  = 3'h1;
  localparam SBOX_UPDATE  = 3'h2;
  localparam MAIN_UPDATE  = 3'h3;
  localparam FINAL_UPDATE = 3'h4;

  localparam CTRL_IDLE  = 3'h0;
  localparam CTRL_INIT  = 3'h1;
  localparam CTRL_SBOX  = 3'h2;
  localparam CTRL_MAIN  = 3'h3;


  //----------------------------------------------------------------
  // Registers.
  //----------------------------------------------------------------
  reg [1 : 0]   sword_ctr_reg;
  reg [1 : 0]   sword_ctr_new;
  reg           sword_ctr_we;
  reg           sword_ctr_inc;
  reg           sword_ctr_rst;

  reg [3 : 0]   round_ctr_reg;
  reg [3 : 0]   round_ctr_new;
  reg           round_ctr_we;
  reg           round_ctr_rst;
  reg           round_ctr_inc;

  reg [127 : 0] block_reg;
  reg [127 : 0] block_new;
  reg [2 : 0]   block_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg [2 : 0]   enc_ctrl_reg;
  reg [2 : 0]   enc_ctrl_new;
  reg           enc_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]  tmp_sboxw;
  reg [127 : 0] tmp_new_block;

  reg [127 : 0] add_roundkey_block;
  reg [127 : 0] shiftrows_block;
  reg [127 : 0] mixcolumns_block;
  reg [127 : 0] subbytes_block;


  //----------------------------------------------------------------
  // Concurrent assignments.
  //----------------------------------------------------------------
  assign round     = round_ctr_reg;
  assign sboxw     = tmp_sboxw;
  assign new_block = tmp_new_block;
  assign ready     = ready_reg;


  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin : reg_update
      if (!reset_n)
        begin
          block_reg     <= 128'h0;
          sword_ctr_reg <= 2'h0;
          round_ctr_reg <= 4'h0;
          ready_reg     <= 1'b1;
          enc_ctrl_reg  <= CTRL_IDLE;
        end
      else
        begin
          if (block_we != NO_UPDATE)
            block_reg <= block_new;

          if (sword_ctr_we)
            sword_ctr_reg <= sword_ctr_new;

          if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (enc_ctrl_we)
            enc_ctrl_reg <= enc_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // round_logic
  //
  // The logic for updating the round counter.
  //----------------------------------------------------------------
  always @*
    begin : round_logic
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'b0;

      if (round_ctr_rst)
        begin
          round_ctr_new = 4'h0;
          round_ctr_we  = 1'b1;
        end
      else if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'b1;
          round_ctr_we  = 1'b1;
        end
    end // round_logic


  //----------------------------------------------------------------
  // sword_ctr
  //
  // The logic for the SubWord counter (S-box word counter).
  // Counts through 0-3 for the 4 S-box operations needed.
  //----------------------------------------------------------------
  always @*
    begin : sword_ctr
      sword_ctr_new = 2'h0;
      sword_ctr_we  = 1'b0;

      if (sword_ctr_rst)
        begin
          sword_ctr_new = 2'h0;
          sword_ctr_we  = 1'b1;
        end
      else if (sword_ctr_inc)
        begin
          sword_ctr_new = sword_ctr_reg + 1'b1;
          sword_ctr_we  = 1'b1;
        end
    end // sword_ctr


  //----------------------------------------------------------------
  // encipher_datapath
  //
  // The main encipher datapath with SubBytes, ShiftRows,
  // MixColumns and AddRoundKey.
  //----------------------------------------------------------------
  always @*
    begin : encipher_datapath
      reg [127 : 0] old_block, tmp_block;
      reg [7 : 0]   tmp_sbox_byte0, tmp_sbox_byte1, tmp_sbox_byte2, tmp_sbox_byte3;

      // Default assignments
      block_new     = 128'h0;
      tmp_sboxw     = 32'h0;
      tmp_new_block = 128'h0;

      // Select SubBytes operation based on sword counter
      tmp_sbox_byte0 = new_sboxw[31 : 24];
      tmp_sbox_byte1 = new_sboxw[23 : 16];
      tmp_sbox_byte2 = new_sboxw[15 : 08];
      tmp_sbox_byte3 = new_sboxw[07 : 00];

      // Use input block for initial round, block_reg for subsequent rounds
      old_block = block_reg;

      // AddRoundKey: XOR with round key
      add_roundkey_block = block ^ round_key;

      // SubBytes: Performed one word (4 bytes) at a time
      // Extract word based on sword_ctr
      case (sword_ctr_reg)
        2'h0: tmp_sboxw = block_reg[127 : 096];
        2'h1: tmp_sboxw = block_reg[095 : 064];
        2'h2: tmp_sboxw = block_reg[063 : 032];
        2'h3: tmp_sboxw = block_reg[031 : 000];
      endcase

      // Update block with SubBytes result
      subbytes_block = block_reg;
      case (sword_ctr_reg)
        2'h0: subbytes_block[127 : 096] = new_sboxw;
        2'h1: subbytes_block[095 : 064] = new_sboxw;
        2'h2: subbytes_block[063 : 032] = new_sboxw;
        2'h3: subbytes_block[031 : 000] = new_sboxw;
      endcase

      // ShiftRows transformation
      // Apply to block_reg which contains completed SubBytes result
      shiftrows_block = shiftrows(block_reg);

      // MixColumns transformation
      mixcolumns_block = mixcolumns(shiftrows_block);

      // Mux for updating the block register
      case (block_we)
        INIT_UPDATE:
          block_new = add_roundkey_block;

        SBOX_UPDATE:
          block_new = subbytes_block;

        MAIN_UPDATE:
          block_new = mixcolumns_block ^ round_key;

        FINAL_UPDATE:
          block_new = shiftrows_block ^ round_key;

        default:
          block_new = block_reg;
      endcase

      // Output assignment - provide final ciphertext
      tmp_new_block = block_reg;
    end // encipher_datapath


  //----------------------------------------------------------------
  // shiftrows
  //
  // ShiftRows transformation function.
  // Shifts row 1 left by 1, row 2 by 2, row 3 by 3.
  //----------------------------------------------------------------
  function [127 : 0] shiftrows(input [127 : 0] block);
    begin
      // AES state is organized as 4x4 matrix in column-major order:
      // block[127:120] block[95:88]  block[63:56]  block[31:24]   <- Row 0
      // block[119:112] block[87:80]  block[55:48]  block[23:16]   <- Row 1
      // block[111:104] block[79:72]  block[47:40]  block[15:8]    <- Row 2
      // block[103:96]  block[71:64]  block[39:32]  block[7:0]     <- Row 3
      //
      // After shifting, reassemble in column-major order:
      
      shiftrows = {// Column 0
                   block[127 : 120], block[087 : 080], block[047 : 040], block[007 : 000],
                   // Column 1
                   block[095 : 088], block[055 : 048], block[015 : 008], block[103 : 096],
                   // Column 2
                   block[063 : 056], block[023 : 016], block[111 : 104], block[071 : 064],
                   // Column 3
                   block[031 : 024], block[119 : 112], block[079 : 072], block[039 : 032]};
    end
  endfunction // shiftrows


  //----------------------------------------------------------------
  // mixcolumns
  //
  // MixColumns transformation function.
  // Performs GF(2^8) matrix multiplication for each column.
  //----------------------------------------------------------------
  function [127 : 0] mixcolumns(input [127 : 0] block);
    reg [7 : 0] b0, b1, b2, b3;
    reg [7 : 0] mb0, mb1, mb2, mb3;
    begin
      // Process each of the 4 columns
      // Column 0
      b0 = block[127 : 120];
      b1 = block[119 : 112];
      b2 = block[111 : 104];
      b3 = block[103 : 096];
      mb0 = gm2(b0) ^ gm3(b1) ^ b2 ^ b3;
      mb1 = b0 ^ gm2(b1) ^ gm3(b2) ^ b3;
      mb2 = b0 ^ b1 ^ gm2(b2) ^ gm3(b3);
      mb3 = gm3(b0) ^ b1 ^ b2 ^ gm2(b3);
      mixcolumns[127 : 096] = {mb0, mb1, mb2, mb3};

      // Column 1
      b0 = block[095 : 088];
      b1 = block[087 : 080];
      b2 = block[079 : 072];
      b3 = block[071 : 064];
      mb0 = gm2(b0) ^ gm3(b1) ^ b2 ^ b3;
      mb1 = b0 ^ gm2(b1) ^ gm3(b2) ^ b3;
      mb2 = b0 ^ b1 ^ gm2(b2) ^ gm3(b3);
      mb3 = gm3(b0) ^ b1 ^ b2 ^ gm2(b3);
      mixcolumns[095 : 064] = {mb0, mb1, mb2, mb3};

      // Column 2
      b0 = block[063 : 056];
      b1 = block[055 : 048];
      b2 = block[047 : 040];
      b3 = block[039 : 032];
      mb0 = gm2(b0) ^ gm3(b1) ^ b2 ^ b3;
      mb1 = b0 ^ gm2(b1) ^ gm3(b2) ^ b3;
      mb2 = b0 ^ b1 ^ gm2(b2) ^ gm3(b3);
      mb3 = gm3(b0) ^ b1 ^ b2 ^ gm2(b3);
      mixcolumns[063 : 032] = {mb0, mb1, mb2, mb3};

      // Column 3
      b0 = block[031 : 024];
      b1 = block[023 : 016];
      b2 = block[015 : 008];
      b3 = block[007 : 000];
      mb0 = gm2(b0) ^ gm3(b1) ^ b2 ^ b3;
      mb1 = b0 ^ gm2(b1) ^ gm3(b2) ^ b3;
      mb2 = b0 ^ b1 ^ gm2(b2) ^ gm3(b3);
      mb3 = gm3(b0) ^ b1 ^ b2 ^ gm2(b3);
      mixcolumns[031 : 000] = {mb0, mb1, mb2, mb3};
    end
  endfunction // mixcolumns


  //----------------------------------------------------------------
  // gm2
  //
  // Galois Field GF(2^8) multiplication by 2.
  //----------------------------------------------------------------
  function [7 : 0] gm2(input [7 : 0] op);
    begin
      gm2 = {op[6 : 0], 1'b0} ^ (8'h1b & {8{op[7]}});
    end
  endfunction // gm2


  //----------------------------------------------------------------
  // gm3
  //
  // Galois Field GF(2^8) multiplication by 3.
  //----------------------------------------------------------------
  function [7 : 0] gm3(input [7 : 0] op);
    begin
      gm3 = gm2(op) ^ op;
    end
  endfunction // gm3


  //----------------------------------------------------------------
  // encipher_ctrl
  //
  // Control FSM for the encipher block.
  //----------------------------------------------------------------
  always @*
    begin : encipher_ctrl
      reg [3 : 0] num_rounds;

      // Default assignments
      ready_new      = 1'b0;
      ready_we       = 1'b0;
      block_we       = NO_UPDATE;
      round_ctr_rst  = 1'b0;
      round_ctr_inc  = 1'b0;
      sword_ctr_rst  = 1'b0;
      sword_ctr_inc  = 1'b0;
      enc_ctrl_new   = CTRL_IDLE;
      enc_ctrl_we    = 1'b0;

      // Determine number of rounds based on key length
      if (keylen == AES_128_BIT_KEY)
        num_rounds = AES_128_NUM_ROUNDS;
      else
        num_rounds = AES_256_NUM_ROUNDS;

      case (enc_ctrl_reg)
        CTRL_IDLE:
          begin
            if (next)
              begin
                ready_new    = 1'b0;
                ready_we     = 1'b1;
                round_ctr_rst = 1'b1;
                enc_ctrl_new = CTRL_INIT;
                enc_ctrl_we  = 1'b1;
              end
          end

        CTRL_INIT:
          begin
            // Initial round: Load input block with AddRoundKey
            block_we      = INIT_UPDATE;
            round_ctr_inc = 1'b1;
            sword_ctr_rst = 1'b1;
            enc_ctrl_new  = CTRL_SBOX;
            enc_ctrl_we   = 1'b1;
            
            $display("[DEBUG] INIT: block=%h, round_key=%h, result=%h", block, round_key, block ^ round_key);
          end

        CTRL_SBOX:
          begin
            // Perform SubBytes transformation (one word per cycle)
            sword_ctr_inc = 1'b1;

            if (sword_ctr_reg < 2'h3)
              begin
                // Still processing S-box words
                block_we = SBOX_UPDATE;
              end
            else
              begin
                // Last S-box word - apply final update and move to MAIN
                block_we     = SBOX_UPDATE;
                enc_ctrl_new = CTRL_MAIN;
                enc_ctrl_we  = 1'b1;
                
                if (round_ctr_reg == 1)
                  $display("[DEBUG] After SubBytes: block=%h", subbytes_block);
              end
          end

        CTRL_MAIN:
          begin
            // ShiftRows + MixColumns + AddRoundKey
            sword_ctr_rst = 1'b1;
            round_ctr_inc = 1'b1;

            if (round_ctr_reg == 1)
              begin
                $display("[DEBUG] MAIN Round 1:");
                $display("  block_reg=%h", block_reg);
                $display("  Byte layout: %h %h %h %h | %h %h %h %h | %h %h %h %h | %h %h %h %h",
                         block_reg[127:120], block_reg[119:112], block_reg[111:104], block_reg[103:96],
                         block_reg[95:88], block_reg[87:80], block_reg[79:72], block_reg[71:64],
                         block_reg[63:56], block_reg[55:48], block_reg[47:40], block_reg[39:32],
                         block_reg[31:24], block_reg[23:16], block_reg[15:8], block_reg[7:0]);
                $display("  shiftrows=%h", shiftrows_block);
                $display("  mixcolumns=%h", mixcolumns_block);
                $display("  round_key=%h", round_key);
                $display("  result=%h", mixcolumns_block ^ round_key);
              end

            if (round_ctr_reg < num_rounds)
              begin
                // Normal round with MixColumns
                block_we     = MAIN_UPDATE;
                enc_ctrl_new = CTRL_SBOX;
                enc_ctrl_we  = 1'b1;
              end
            else
              begin
                // Final round without MixColumns
                block_we     = FINAL_UPDATE;
                ready_new    = 1'b1;
                ready_we     = 1'b1;
                enc_ctrl_new = CTRL_IDLE;
                enc_ctrl_we  = 1'b1;
                $display("[DEBUG] FINAL: block_reg=%h, result=%h", block_reg, shiftrows_block ^ round_key);
              end
          end

        default:
          begin
          end
      endcase // case (enc_ctrl_reg)
    end // encipher_ctrl

endmodule // aes_encipher_block

//======================================================================
// EOF aes_encipher_block.v
//======================================================================
