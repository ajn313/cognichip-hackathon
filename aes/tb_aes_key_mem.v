//======================================================================
//
// tb_aes_key_mem.v
// ----------------
// Testbench for the AES key memory module.
// Tests key expansion for both AES-128 and AES-256.
//
//======================================================================

`timescale 1ns/1ps

module tb_aes_key_mem;

  //----------------------------------------------------------------
  // Internal constants and parameters.
  //----------------------------------------------------------------
  parameter CLK_PERIOD = 10;
  parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

  localparam AES_128_BIT_KEY = 1'h0;
  localparam AES_256_BIT_KEY = 1'h1;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg            tb_clk;
  reg            tb_reset;
  reg [255 : 0]  tb_key;
  reg            tb_keylen;
  reg            tb_init;
  reg [3 : 0]    tb_round;
  wire [127 : 0] tb_round_key;
  wire           tb_ready;
  wire [31 : 0]  tb_sboxw;
  wire [31 : 0]  tb_new_sboxw;

  reg [31 : 0]   read_data;
  integer        errors;
  integer        tc_ctr;

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  aes_key_mem dut(
                  .clk(tb_clk),
                  .reset(tb_reset),
                  .key(tb_key),
                  .keylen(tb_keylen),
                  .init(tb_init),
                  .round(tb_round),
                  .round_key(tb_round_key),
                  .ready(tb_ready),
                  .sboxw(tb_sboxw),
                  .new_sboxw(tb_new_sboxw)
                 );

  //----------------------------------------------------------------
  // S-box instantiation for key expansion.
  // The key_mem needs 4 parallel S-boxes for the 4 bytes.
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
  // Toggles reset to force the DUT into a well defined state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("Resetting DUT...");
      tb_reset = 1'b1;
      #(2 * CLK_PERIOD);
      tb_reset = 1'b0;
      #(2 * CLK_PERIOD);
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // init_sim
  //
  // Initialize all counters and testbed functionality.
  //----------------------------------------------------------------
  task init_sim;
    begin
      tb_clk    = 1'b0;
      tb_reset  = 1'b0;
      tb_key    = 256'h0;
      tb_keylen = AES_128_BIT_KEY;
      tb_init   = 1'b0;
      tb_round  = 4'h0;
      errors    = 0;
      tc_ctr    = 0;
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
  // test_key_128
  //
  // Test AES-128 key expansion with known test vector.
  // Using FIPS-197 Appendix A.1 test vector.
  //----------------------------------------------------------------
  task test_key_128;
    begin
      tc_ctr = tc_ctr + 1;
      $display("*** Test case %0d: AES-128 key expansion", tc_ctr);

      // Test vector from FIPS-197 Appendix A.1
      // Key: 2b7e151628aed2a6abf7158809cf4f3c
      tb_key    = 256'h2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000;
      tb_keylen = AES_128_BIT_KEY;
      tb_init   = 1'b1;
      #CLK_PERIOD;
      tb_init   = 1'b0;

      // Wait for key expansion to complete
      wait_ready();
      $display("Key expansion completed, checking round keys...");

      // Check round key 0 (original key)
      tb_round = 4'h0;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h2b7e151628aed2a6abf7158809cf4f3c) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[0] : expected_value: 128'h2b7e151628aed2a6abf7158809cf4f3c actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[0] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 1
      tb_round = 4'h1;
      #CLK_PERIOD;
      if (tb_round_key !== 128'ha0fafe1788542cb123a339392a6c7605) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[1] : expected_value: 128'ha0fafe1788542cb123a339392a6c7605 actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[1] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 10 (final round key)
      tb_round = 4'ha;
      #CLK_PERIOD;
      if (tb_round_key !== 128'hd014f9a8c9ee2589e13f0cc8b6630ca6) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[10] : expected_value: 128'hd014f9a8c9ee2589e13f0cc8b6630ca6 actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[10] : expected_value: PASS actual_value: PASS", $time);
      end

      if (errors == 0) begin
        $display("*** Test case %0d completed successfully", tc_ctr);
      end else begin
        $display("*** Test case %0d FAILED", tc_ctr);
      end

      #(2 * CLK_PERIOD);
    end
  endtask // test_key_128


  //----------------------------------------------------------------
  // test_key_256
  //
  // Test AES-256 key expansion with known test vector.
  // Using FIPS-197 Appendix A.3 test vector.
  //----------------------------------------------------------------
  task test_key_256;
    begin
      tc_ctr = tc_ctr + 1;
      $display("*** Test case %0d: AES-256 key expansion", tc_ctr);

      // Test vector from FIPS-197 Appendix A.3 (Test Case 3)
      // Key: 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
      tb_key    = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
      tb_keylen = AES_256_BIT_KEY;
      tb_init   = 1'b1;
      #CLK_PERIOD;
      tb_init   = 1'b0;

      // Wait for key expansion to complete
      wait_ready();
      $display("Key expansion completed, checking round keys...");

      // Check round key 0 (first half of original key)
      tb_round = 4'h0;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h000102030405060708090a0b0c0d0e0f) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[0] : expected_value: 128'h000102030405060708090a0b0c0d0e0f actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[0] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 1 (second half of input key)
      tb_round = 4'h1;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h101112131415161718191a1b1c1d1e1f) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[1] : expected_value: 128'h101112131415161718191a1b1c1d1e1f actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[1] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 2 (first generated - FIPS-197 Appendix A.3)
      tb_round = 4'h2;
      #CLK_PERIOD;
      if (tb_round_key !== 128'ha573c29fa176c498a97fce93a572c09c) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[2] : expected_value: 128'ha573c29fa176c498a97fce93a572c09c actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[2] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 3
      tb_round = 4'h3;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h1651a8cd0244beda1a5da4c10640bade) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[3] : expected_value: 128'h1651a8cd0244beda1a5da4c10640bade actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[3] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 4
      tb_round = 4'h4;
      #CLK_PERIOD;
      if (tb_round_key !== 128'hae87dff00ff11b68a68ed5fb03fc1567) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[4] : expected_value: 128'hae87dff00ff11b68a68ed5fb03fc1567 actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[4] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 5
      tb_round = 4'h5;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h6de1f1486fa54f9275f8eb5373b8518d) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[5] : expected_value: 128'h6de1f1486fa54f9275f8eb5373b8518d actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[5] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 6
      tb_round = 4'h6;
      #CLK_PERIOD;
      if (tb_round_key !== 128'hc656827fc9a799176f294cec6cd5598b) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[6] : expected_value: 128'hc656827fc9a799176f294cec6cd5598b actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[6] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 10
      tb_round = 4'ha;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h7ccff71cbeb4fe5413e6bbf0d261a7df) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[10] : expected_value: 128'h7ccff71cbeb4fe5413e6bbf0d261a7df actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[10] : expected_value: PASS actual_value: PASS", $time);
      end

      // Check round key 14 (final round key for AES-256)
      tb_round = 4'he;
      #CLK_PERIOD;
      if (tb_round_key !== 128'h24fc79ccbf0979e9371ac23c6d68de36) begin
        $display("LOG: %0t : ERROR : tb_aes_key_mem : dut.round_key[14] : expected_value: 128'h24fc79ccbf0979e9371ac23c6d68de36 actual_value: 128'h%032h", 
                 $time, tb_round_key);
        errors = errors + 1;
      end else begin
        $display("LOG: %0t : INFO : tb_aes_key_mem : dut.round_key[14] : expected_value: PASS actual_value: PASS", $time);
      end

      if (errors == 0) begin
        $display("*** Test case %0d completed successfully", tc_ctr);
      end else begin
        $display("*** Test case %0d FAILED", tc_ctr);
      end

      #(2 * CLK_PERIOD);
    end
  endtask // test_key_256


  //----------------------------------------------------------------
  // Main test process.
  //----------------------------------------------------------------
  initial begin
    $display("TEST START");
    $display("===================================");
    $display("Testbench for AES Key Memory");
    $display("===================================");

    init_sim();
    reset_dut();

    // Run test cases
    test_key_128();
    test_key_256();

    // Final result
    #10;
    $display("===================================");
    if (errors == 0) begin
      $display("TEST PASSED");
      $display("All %0d test cases completed successfully", tc_ctr);
    end else begin
      $display("TEST FAILED");
      $display("Total errors: %0d", errors);
      $error("AES key memory verification failed with %0d errors", errors);
    end
    $display("===================================");

    $finish;
  end

  //----------------------------------------------------------------
  // Waveform dump
  //----------------------------------------------------------------
  initial begin
    $dumpfile("dumpfile.fst");
    $dumpvars(0);
  end

endmodule // tb_aes_key_mem

//======================================================================
// EOF tb_aes_key_mem.v
//======================================================================
