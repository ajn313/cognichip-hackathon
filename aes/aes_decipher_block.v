//======================================================================
//
// aes_decipher_block.v
// --------------------
// The AES decipher block that performs decryption rounds.
// Implements InvSubBytes, InvShiftRows, InvMixColumns, and AddRoundKey.
// Supports both AES-128 and AES-256.
//
//======================================================================

module aes_decipher_block(
                          input wire            clk,
                          input wire            reset_n,

                          input wire            next,
                          input wire            keylen,

                          output wire [3 : 0]   round,
                          input wire [127 : 0]  round_key,

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
  localparam SHIFT_UPDATE = 3'h2;
  localparam SBOX_UPDATE  = 3'h3;
  localparam KEY_UPDATE   = 3'h4;
  localparam MIX_UPDATE   = 3'h5;
  localparam FINAL_UPDATE = 3'h6;

  localparam CTRL_IDLE  = 3'h0;
  localparam CTRL_INIT  = 3'h1;
  localparam CTRL_SHIFT = 3'h2;
  localparam CTRL_SBOX  = 3'h3;
  localparam CTRL_KEY   = 3'h4;
  localparam CTRL_MIX   = 3'h5;


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
  reg           round_ctr_set;
  reg           round_ctr_dec;

  reg [127 : 0] block_reg;
  reg [127 : 0] block_new;
  reg [2 : 0]   block_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg [2 : 0]   dec_ctrl_reg;
  reg [2 : 0]   dec_ctrl_new;
  reg           dec_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  wire [31 : 0] inv_sboxw0, inv_sboxw1, inv_sboxw2, inv_sboxw3;
  wire [31 : 0] inv_new_sboxw;
  reg [31 : 0]  tmp_inv_sboxw;

  reg [127 : 0] tmp_new_block;
  reg [127 : 0] add_roundkey_block;
  reg [127 : 0] inv_shiftrows_block;
  reg [127 : 0] inv_mixcolumns_block;
  reg [127 : 0] inv_subbytes_block;


  //----------------------------------------------------------------
  // Inverse S-box instantiations.
  // Four parallel inverse S-boxes for processing one word (4 bytes).
  //----------------------------------------------------------------
  aes_inv_sbox inv_sbox_inst0(.sboxw(tmp_inv_sboxw[31 : 24]), 
                               .new_sboxw(inv_new_sboxw[31 : 24]));

  aes_inv_sbox inv_sbox_inst1(.sboxw(tmp_inv_sboxw[23 : 16]), 
                               .new_sboxw(inv_new_sboxw[23 : 16]));

  aes_inv_sbox inv_sbox_inst2(.sboxw(tmp_inv_sboxw[15 : 08]), 
                               .new_sboxw(inv_new_sboxw[15 : 08]));

  aes_inv_sbox inv_sbox_inst3(.sboxw(tmp_inv_sboxw[07 : 00]), 
                               .new_sboxw(inv_new_sboxw[07 : 00]));


  //----------------------------------------------------------------
  // Concurrent assignments.
  //----------------------------------------------------------------
  assign round     = round_ctr_reg;
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
          dec_ctrl_reg  <= CTRL_IDLE;
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

          if (dec_ctrl_we)
            dec_ctrl_reg <= dec_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // round_logic
  //
  // The logic for updating the round counter.
  // For decryption, we COUNT DOWN from num_rounds to 0.
  //----------------------------------------------------------------
  always @*
    begin : round_logic
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'b0;

      if (round_ctr_set)
        begin
          // Set to num_rounds (start from last round key)
          if (keylen == AES_128_BIT_KEY)
            round_ctr_new = AES_128_NUM_ROUNDS;
          else
            round_ctr_new = AES_256_NUM_ROUNDS;
          round_ctr_we = 1'b1;
        end
      else if (round_ctr_dec)
        begin
          round_ctr_new = round_ctr_reg - 1'b1;
          round_ctr_we  = 1'b1;
        end
    end // round_logic


  //----------------------------------------------------------------
  // sword_ctr
  //
  // The logic for the SubWord counter (S-box word counter).
  // Counts through 0-3 for the 4 inverse S-box operations needed.
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
  // decipher_datapath
  //
  // The main decipher datapath with InvSubBytes, InvShiftRows,
  // InvMixColumns and AddRoundKey.
  //----------------------------------------------------------------
  always @*
    begin : decipher_datapath
      reg [127 : 0] tmp_block;

      // Default assignments
      block_new        = 128'h0;
      tmp_inv_sboxw    = 32'h0;
      tmp_new_block    = 128'h0;

      // AddRoundKey: XOR with round key (same as encryption)
      add_roundkey_block = block ^ round_key;

      // InvSubBytes: Performed one word (4 bytes) at a time
      // Extract word based on sword_ctr
      case (sword_ctr_reg)
        2'h0: tmp_inv_sboxw = block_reg[127 : 096];
        2'h1: tmp_inv_sboxw = block_reg[095 : 064];
        2'h2: tmp_inv_sboxw = block_reg[063 : 032];
        2'h3: tmp_inv_sboxw = block_reg[031 : 000];
      endcase

      // Update block with InvSubBytes result
      inv_subbytes_block = block_reg;
      case (sword_ctr_reg)
        2'h0: inv_subbytes_block[127 : 096] = inv_new_sboxw;
        2'h1: inv_subbytes_block[095 : 064] = inv_new_sboxw;
        2'h2: inv_subbytes_block[063 : 032] = inv_new_sboxw;
        2'h3: inv_subbytes_block[031 : 000] = inv_new_sboxw;
      endcase

      // InvShiftRows transformation (operates on block_reg)
      inv_shiftrows_block = inv_shiftrows(block_reg);

      // InvMixColumns transformation (operates on block_reg)
      inv_mixcolumns_block = inv_mixcolumns(block_reg);

      // Mux for updating the block register
      case (block_we)
        INIT_UPDATE:
          // Initial round: AddRoundKey only
          block_new = add_roundkey_block;

        SHIFT_UPDATE:
          // Update with InvShiftRows result
          block_new = inv_shiftrows_block;

        SBOX_UPDATE:
          // Update with InvSubBytes result
          block_new = inv_subbytes_block;

        KEY_UPDATE:
          // AddRoundKey (applied in CTRL_KEY state)
          block_new = block_reg ^ round_key;

        MIX_UPDATE:
          // Apply InvMixColumns (in CTRL_MIX state)
          block_new = inv_mixcolumns_block;

        FINAL_UPDATE:
          // AddRoundKey for final round
          block_new = block_reg ^ round_key;

        default:
          block_new = block_reg;
      endcase

      // Output assignment - provide final plaintext
      tmp_new_block = block_reg;
    end // decipher_datapath


  //----------------------------------------------------------------
  // inv_shiftrows
  //
  // InvShiftRows transformation function.
  // Shifts row 1 RIGHT by 1, row 2 RIGHT by 2, row 3 RIGHT by 3.
  // (Equivalent to left shift by 3, 2, 1 respectively)
  //----------------------------------------------------------------
  function [127 : 0] inv_shiftrows(input [127 : 0] block);
    begin
      // AES state in column-major order, shift rows RIGHT:
      // block[127:120] block[95:88]  block[63:56]  block[31:24]   <- Row 0
      // block[119:112] block[87:80]  block[55:48]  block[23:16]   <- Row 1
      // block[111:104] block[79:72]  block[47:40]  block[15:8]    <- Row 2
      // block[103:96]  block[71:64]  block[39:32]  block[7:0]     <- Row 3
      //
      // After shifting RIGHT, reassemble in column-major order:
      // Row 0: no shift     [7a  89  2b  3d] → [7a  89  2b  3d]
      // Row 1: shift right 1 [d5  ef  ca  9f] → [9f  d5  ef  ca]
      // Row 2: shift right 2 [fd  4e  10  f5] → [10  f5  fd  4e]
      // Row 3: shift right 3 [a7  27  0b  9f] → [0b  9f  a7  27]
      
      inv_shiftrows = {// Column 0
                       block[127 : 120], block[023 : 016], block[047 : 040], block[039 : 032],
                       // Column 1
                       block[095 : 088], block[119 : 112], block[015 : 008], block[007 : 000],
                       // Column 2
                       block[063 : 056], block[087 : 080], block[111 : 104], block[103 : 096],
                       // Column 3
                       block[031 : 024], block[055 : 048], block[079 : 072], block[071 : 064]};
    end
  endfunction // inv_shiftrows


  //----------------------------------------------------------------
  // inv_mixcolumns
  //
  // InvMixColumns transformation function.
  // Performs inverse GF(2^8) matrix multiplication for each column.
  // Uses multipliers: 14, 11, 13, 9
  //----------------------------------------------------------------
  function [127 : 0] inv_mixcolumns(input [127 : 0] block);
    reg [7 : 0] b0, b1, b2, b3;
    reg [7 : 0] mb0, mb1, mb2, mb3;
    begin
      // Process each of the 4 columns
      // Column 0
      b0 = block[127 : 120];
      b1 = block[119 : 112];
      b2 = block[111 : 104];
      b3 = block[103 : 096];
      mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm9(b3);
      mb1 = gm9(b0) ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
      mb2 = gm13(b0) ^ gm9(b1) ^ gm14(b2) ^ gm11(b3);
      mb3 = gm11(b0) ^ gm13(b1) ^ gm9(b2) ^ gm14(b3);
      inv_mixcolumns[127 : 096] = {mb0, mb1, mb2, mb3};

      // Column 1
      b0 = block[095 : 088];
      b1 = block[087 : 080];
      b2 = block[079 : 072];
      b3 = block[071 : 064];
      mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm9(b3);
      mb1 = gm9(b0) ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
      mb2 = gm13(b0) ^ gm9(b1) ^ gm14(b2) ^ gm11(b3);
      mb3 = gm11(b0) ^ gm13(b1) ^ gm9(b2) ^ gm14(b3);
      inv_mixcolumns[095 : 064] = {mb0, mb1, mb2, mb3};

      // Column 2
      b0 = block[063 : 056];
      b1 = block[055 : 048];
      b2 = block[047 : 040];
      b3 = block[039 : 032];
      mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm9(b3);
      mb1 = gm9(b0) ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
      mb2 = gm13(b0) ^ gm9(b1) ^ gm14(b2) ^ gm11(b3);
      mb3 = gm11(b0) ^ gm13(b1) ^ gm9(b2) ^ gm14(b3);
      inv_mixcolumns[063 : 032] = {mb0, mb1, mb2, mb3};

      // Column 3
      b0 = block[031 : 024];
      b1 = block[023 : 016];
      b2 = block[015 : 008];
      b3 = block[007 : 000];
      mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm9(b3);
      mb1 = gm9(b0) ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
      mb2 = gm13(b0) ^ gm9(b1) ^ gm14(b2) ^ gm11(b3);
      mb3 = gm11(b0) ^ gm13(b1) ^ gm9(b2) ^ gm14(b3);
      inv_mixcolumns[031 : 000] = {mb0, mb1, mb2, mb3};
    end
  endfunction // inv_mixcolumns


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
  // gm4
  //
  // Galois Field GF(2^8) multiplication by 4.
  //----------------------------------------------------------------
  function [7 : 0] gm4(input [7 : 0] op);
    begin
      gm4 = gm2(gm2(op));
    end
  endfunction // gm4


  //----------------------------------------------------------------
  // gm8
  //
  // Galois Field GF(2^8) multiplication by 8.
  //----------------------------------------------------------------
  function [7 : 0] gm8(input [7 : 0] op);
    begin
      gm8 = gm2(gm4(op));
    end
  endfunction // gm8


  //----------------------------------------------------------------
  // gm9
  //
  // Galois Field GF(2^8) multiplication by 9 (0x09).
  // 9 = 8 + 1
  //----------------------------------------------------------------
  function [7 : 0] gm9(input [7 : 0] op);
    begin
      gm9 = gm8(op) ^ op;
    end
  endfunction // gm9


  //----------------------------------------------------------------
  // gm11
  //
  // Galois Field GF(2^8) multiplication by 11 (0x0b).
  // 11 = 8 + 2 + 1
  //----------------------------------------------------------------
  function [7 : 0] gm11(input [7 : 0] op);
    begin
      gm11 = gm8(op) ^ gm2(op) ^ op;
    end
  endfunction // gm11


  //----------------------------------------------------------------
  // gm13
  //
  // Galois Field GF(2^8) multiplication by 13 (0x0d).
  // 13 = 8 + 4 + 1
  //----------------------------------------------------------------
  function [7 : 0] gm13(input [7 : 0] op);
    begin
      gm13 = gm8(op) ^ gm4(op) ^ op;
    end
  endfunction // gm13


  //----------------------------------------------------------------
  // gm14
  //
  // Galois Field GF(2^8) multiplication by 14 (0x0e).
  // 14 = 8 + 4 + 2
  //----------------------------------------------------------------
  function [7 : 0] gm14(input [7 : 0] op);
    begin
      gm14 = gm8(op) ^ gm4(op) ^ gm2(op);
    end
  endfunction // gm14


  //----------------------------------------------------------------
  // decipher_ctrl
  //
  // Control FSM for the decipher block.
  // Decryption processes rounds in REVERSE order.
  //----------------------------------------------------------------
  always @*
    begin : decipher_ctrl
      reg [3 : 0] num_rounds;

      // Default assignments
      ready_new      = 1'b0;
      ready_we       = 1'b0;
      block_we       = NO_UPDATE;
      round_ctr_set  = 1'b0;
      round_ctr_dec  = 1'b0;
      sword_ctr_rst  = 1'b0;
      sword_ctr_inc  = 1'b0;
      dec_ctrl_new   = CTRL_IDLE;
      dec_ctrl_we    = 1'b0;

      // Determine number of rounds based on key length
      if (keylen == AES_128_BIT_KEY)
        num_rounds = AES_128_NUM_ROUNDS;
      else
        num_rounds = AES_256_NUM_ROUNDS;

      case (dec_ctrl_reg)
        CTRL_IDLE:
          begin
            if (next)
              begin
                ready_new     = 1'b0;
                ready_we      = 1'b1;
                round_ctr_set = 1'b1;
                dec_ctrl_new  = CTRL_INIT;
                dec_ctrl_we   = 1'b1;
              end
          end

        CTRL_INIT:
          begin
            // Initial round: AddRoundKey with last round key
            block_we      = INIT_UPDATE;
            dec_ctrl_new  = CTRL_SHIFT;
            dec_ctrl_we   = 1'b1;
            
            if (keylen == AES_128_BIT_KEY)
              $display("[DEBUG] INIT DEC: cipher=%h, key=%h, result=%h", block, round_key, block ^ round_key);
          end

        CTRL_SHIFT:
          begin
            // Apply InvShiftRows (BEFORE InvSubBytes per Equivalent Inverse Cipher)
            block_we      = SHIFT_UPDATE;
            sword_ctr_rst = 1'b1;
            dec_ctrl_new  = CTRL_SBOX;
            dec_ctrl_we   = 1'b1;
            
            if (round_ctr_reg == 4'ha && keylen == AES_128_BIT_KEY)
              $display("[DEBUG] After InvShiftRows: %h", inv_shiftrows_block);
          end

        CTRL_SBOX:
          begin
            // Perform InvSubBytes transformation (one word per cycle)
            sword_ctr_inc = 1'b1;

            if (sword_ctr_reg < 2'h3)
              begin
                // Still processing inverse S-box words
                block_we = SBOX_UPDATE;
              end
            else
              begin
                // Last S-box word - apply final update and move to KEY
                block_we     = SBOX_UPDATE;
                dec_ctrl_new = CTRL_KEY;
                dec_ctrl_we  = 1'b1;
                
                if (round_ctr_reg == 4'ha && keylen == AES_128_BIT_KEY)
                  $display("[DEBUG] After InvSubBytes: %h", inv_subbytes_block);
              end
          end

        CTRL_KEY:
          begin
            // Apply AddRoundKey
            round_ctr_dec = 1'b1;
            
            if (round_ctr_reg == 4'ha && keylen == AES_128_BIT_KEY)
              $display("[DEBUG] AddRoundKey: block_reg=%h, key=%h, result=%h", block_reg, round_key, block_reg ^ round_key);
            
            if (round_ctr_reg > 4'h1)
              begin
                // Normal round: AddRoundKey then InvMixColumns
                block_we     = KEY_UPDATE;
                dec_ctrl_new = CTRL_MIX;
                dec_ctrl_we  = 1'b1;
              end
            else
              begin
                // Final round: AddRoundKey only (no InvMixColumns)
                block_we     = FINAL_UPDATE;
                ready_new    = 1'b1;
                ready_we     = 1'b1;
                dec_ctrl_new = CTRL_IDLE;
                dec_ctrl_we  = 1'b1;
                
                if (keylen == AES_128_BIT_KEY)
                  $display("[DEBUG] FINAL: block_reg=%h, key=%h, result=%h", block_reg, round_key, block_reg ^ round_key);
              end
          end

        CTRL_MIX:
          begin
            // Apply InvMixColumns (operates on AddRoundKey result in block_reg)
            block_we     = MIX_UPDATE;
            dec_ctrl_new = CTRL_SHIFT;
            dec_ctrl_we  = 1'b1;
            
            if (round_ctr_reg == 4'h9 && keylen == AES_128_BIT_KEY)
              $display("[DEBUG] After InvMixColumns: %h", inv_mixcolumns_block);
          end

        default:
          begin
          end
      endcase // case (dec_ctrl_reg)
    end // decipher_ctrl

endmodule // aes_decipher_block

//======================================================================
// EOF aes_decipher_block.v
//======================================================================
