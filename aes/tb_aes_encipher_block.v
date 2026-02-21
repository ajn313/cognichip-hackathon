//======================================================================
//
// tb_aes_encipher_block.v
// -----------------------
// Testbench for the AES encipher block module.
// Tests encryption for both AES-128 and AES-256 using FIPS-197
// test vectors.
//
//======================================================================

`timescale 1ns/1ps

module tb_aes_encipher_block;

  //----------------------------------------------------------------
  // Parameters.
  //----------------------------------------------------------------
  parameter CLK_PERIOD = 10;
  parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

  localparam AES_128_BIT_KEY = 1'h0;
  localparam AES_256_BIT_KEY = 1'h1;


  //----------------------------------------------------------------
  // Register and wire declarations.
  //----------------------------------------------------------------
  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_next;
  reg            tb_keylen;
  wire [3 : 0]   tb_round;
  wire [127 : 0] tb_round_key;
  wire [31 : 0]  tb_sboxw;
  wire [31 : 0]  tb_new_sboxw;
  reg [127 : 0]  tb_block;
  wire [127 : 0] tb_new_block;
  wire           tb_ready;

  reg [127 : 0]  key_mem [0 : 14];
  integer        errors;
  integer        tc_ctr;


  //----------------------------------------------------------------
  // Assignments.
  //----------------------------------------------------------------
  assign tb_round_key = key_mem[tb_round];


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  aes_encipher_block dut(
                         .clk(tb_clk),
                         .reset_n(tb_reset_n),
                         .next(tb_next),
                         .keylen(tb_keylen),
                         .round(tb_round),
                         .round_key(tb_round_key),
                         .sboxw(tb_sboxw),
                         .new_sboxw(tb_new_sboxw),
                         .block(tb_block),
                         .new_block(tb_new_block),
                         .ready(tb_ready)
                        );


  //----------------------------------------------------------------
  // S-box instantiation.
  // The encipher block uses one 32-bit S-box (4 parallel bytes).
  //----------------------------------------------------------------
  aes_sbox sbox_inst0(
                      .sboxw(tb_sboxw[31 : 24]),
                      .new_sboxw(tb_new_sboxw[31 : 24])
                     );

  aes_sbox sbox_inst1(
                      .sboxw(tb_sboxw[23 : 16]),
                      .new_sboxw(tb_new_sboxw[23 : 16])
                     );

  aes_sbox sbox_inst2(
                      .sboxw(tb_sboxw[15 : 08]),
                      .new_sboxw(tb_new_sboxw[15 : 08])
                     );

  aes_sbox sbox_inst3(
                      .sboxw(tb_sboxw[07 : 00]),
                      .new_sboxw(tb_new_sboxw[07 : 00])
                     );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // reset_dut
  //
  // Toggle reset to put DUT into known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("Resetting DUT...");
      tb_reset_n = 1'b0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1'b1;
      #(2 * CLK_PERIOD);
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // init_sim
  //
  // Initialize all counters and testbench functionality.
  //----------------------------------------------------------------
  task init_sim;
    begin
      tb_clk     = 1'b0;
      tb_reset_n = 1'b1;
      tb_next    = 1'b0;
      tb_keylen  = AES_128_BIT_KEY;
      tb_block   = 128'h0;
      errors     = 0;
      tc_ctr     = 0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // wait_ready
  //
  // Wait for the ready flag to be set in DUT.
  //----------------------------------------------------------------
  task wait_ready;
    begin
      while (!tb_ready)
        #CLK_PERIOD;
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // test_aes_128_enc
  //
  // Test AES-128 encryption with FIPS-197 Appendix C.1 test vector.
  //----------------------------------------------------------------
  task test_aes_128_enc;
    begin
      tc_ctr = tc_ctr + 1;
      $display("*** Test case %0d: AES-128 encryption", tc_ctr);

      // FIPS-197 Appendix C.1 test vector
      // Plaintext: 00112233445566778899aabbccddeeff
      // Key:       000102030405060708090a0b0c0d0e0f
      // Expected:  69c4e0d86a7b0430d8cdb78070b4c55a

      // Load pre-computed round keys
      key_mem[0]  = 128'h000102030405060708090a0b0c0d0e0f;
      key_mem[1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
      key_mem[2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
      key_mem[3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
      key_mem[4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
      key_mem[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
      key_mem[6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
      key_mem[7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
      key_mem[8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
      key_mem[9]  = 128'h549932d1f08557681093ed9cbe2c974e;
      key_mem[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;

      tb_block  = 128'h00112233445566778899aabbccddeeff;
      tb_keylen = AES_128_BIT_KEY;
      tb_next   = 1'b1;
      #CLK_PERIOD;
      tb_next   = 1'b0;

      // Wait for encryption to complete
      wait_ready();
      #CLK_PERIOD;

      $display("Encryption completed, checking result...");
      if (tb_new_block !== 128'h69c4e0d86a7b0430d8cdb78070b4c55a)
        begin
          $display("LOG: %0t : ERROR : tb_aes_encipher_block : dut.new_block : expected_value: 128'h69c4e0d86a7b0430d8cdb78070b4c55a actual_value: 128'h%032h",
                   $time, tb_new_block);
          errors = errors + 1;
        end
      else
        begin
          $display("LOG: %0t : INFO : tb_aes_encipher_block : dut.new_block : expected_value: PASS actual_value: PASS", $time);
        end

      if (errors == 0)
        begin
          $display("*** Test case %0d completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** Test case %0d FAILED", tc_ctr);
        end

      #(2 * CLK_PERIOD);
    end
  endtask // test_aes_128_enc


  //----------------------------------------------------------------
  // test_aes_256_enc
  //
  // Test AES-256 encryption with FIPS-197 Appendix C.3 test vector.
  //----------------------------------------------------------------
  task test_aes_256_enc;
    begin
      tc_ctr = tc_ctr + 1;
      $display("*** Test case %0d: AES-256 encryption", tc_ctr);

      // FIPS-197 Appendix C.3 test vector
      // Plaintext: 00112233445566778899aabbccddeeff
      // Key:       000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
      // Expected:  8ea2b7ca516745bfeafc49904b496089

      // Load pre-computed round keys (from our aes_key_mem test)
      key_mem[0]  = 128'h000102030405060708090a0b0c0d0e0f;
      key_mem[1]  = 128'h101112131415161718191a1b1c1d1e1f;
      key_mem[2]  = 128'ha573c29fa176c498a97fce93a572c09c;
      key_mem[3]  = 128'h1651a8cd0244beda1a5da4c10640bade;
      key_mem[4]  = 128'hae87dff00ff11b68a68ed5fb03fc1567;
      key_mem[5]  = 128'h6de1f1486fa54f9275f8eb5373b8518d;
      key_mem[6]  = 128'hc656827fc9a799176f294cec6cd5598b;
      key_mem[7]  = 128'h3de23a75524775e727bf9eb45407cf39;
      key_mem[8]  = 128'h0bdc905fc27b0948ad5245a4c1871c2f;
      key_mem[9]  = 128'h45f5a66017b2d387300d4d33640a820a;
      key_mem[10] = 128'h7ccff71cbeb4fe5413e6bbf0d261a7df;
      key_mem[11] = 128'hf01afafee7a82979d7a5644ab3afe640;
      key_mem[12] = 128'h2541fe719bf500258813bbd55a721c0a;
      key_mem[13] = 128'h4e5a6699a9f24fe07e572baacdf8cdea;
      key_mem[14] = 128'h24fc79ccbf0979e9371ac23c6d68de36;

      tb_block  = 128'h00112233445566778899aabbccddeeff;
      tb_keylen = AES_256_BIT_KEY;
      tb_next   = 1'b1;
      #CLK_PERIOD;
      tb_next   = 1'b0;

      // Wait for encryption to complete
      wait_ready();
      #CLK_PERIOD;

      $display("Encryption completed, checking result...");
      if (tb_new_block !== 128'h8ea2b7ca516745bfeafc49904b496089)
        begin
          $display("LOG: %0t : ERROR : tb_aes_encipher_block : dut.new_block : expected_value: 128'h8ea2b7ca516745bfeafc49904b496089 actual_value: 128'h%032h",
                   $time, tb_new_block);
          errors = errors + 1;
        end
      else
        begin
          $display("LOG: %0t : INFO : tb_aes_encipher_block : dut.new_block : expected_value: PASS actual_value: PASS", $time);
        end

      if (errors == 0)
        begin
          $display("*** Test case %0d completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** Test case %0d FAILED", tc_ctr);
        end

      #(2 * CLK_PERIOD);
    end
  endtask // test_aes_256_enc


  //----------------------------------------------------------------
  // Main test process.
  //----------------------------------------------------------------
  initial
    begin
      $display("TEST START");
      $display("===================================");
      $display("Testbench for AES Encipher Block");
      $display("===================================");

      init_sim();
      reset_dut();

      // Run test cases
      test_aes_128_enc();
      test_aes_256_enc();

      // Final result
      #10;
      $display("===================================");
      if (errors == 0)
        begin
          $display("TEST PASSED");
          $display("All %0d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("TEST FAILED");
          $display("Total errors: %0d", errors);
          $error("AES encipher block verification failed with %0d errors", errors);
        end
      $display("===================================");

      $finish;
    end


  //----------------------------------------------------------------
  // Waveform dump
  //----------------------------------------------------------------
  initial
    begin
      $dumpfile("dumpfile.fst");
      $dumpvars(0);
    end

endmodule // tb_aes_encipher_block

//======================================================================
// EOF tb_aes_encipher_block.v
//======================================================================
