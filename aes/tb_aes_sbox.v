//======================================================================
//
// tb_aes_sbox.v
// -------------
// Testbench for the AES S-box module.
// Tests all 256 S-box entries against expected values.
//
//======================================================================

`timescale 1ns/1ps

module tb_aes_sbox;

  //----------------------------------------------------------------
  // Internal constants and parameters.
  //----------------------------------------------------------------
  parameter CLK_PERIOD = 10;
  parameter NUM_TESTS = 256;

  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [7 : 0]  tb_sboxw;
  wire [7 : 0] tb_new_sboxw;
  
  reg [7 : 0]  expected_sbox [0 : 255];
  integer      i;
  integer      errors;

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  aes_sbox dut(
               .sboxw(tb_sboxw),
               .new_sboxw(tb_new_sboxw)
              );

  //----------------------------------------------------------------
  // init_sbox_table
  //
  // Initialize the expected S-box lookup table based on
  // AES specification (FIPS-197).
  //----------------------------------------------------------------
  task init_sbox_table;
    begin
      expected_sbox[8'h00] = 8'h63;
      expected_sbox[8'h01] = 8'h7c;
      expected_sbox[8'h02] = 8'h77;
      expected_sbox[8'h03] = 8'h7b;
      expected_sbox[8'h04] = 8'hf2;
      expected_sbox[8'h05] = 8'h6b;
      expected_sbox[8'h06] = 8'h6f;
      expected_sbox[8'h07] = 8'hc5;
      expected_sbox[8'h08] = 8'h30;
      expected_sbox[8'h09] = 8'h01;
      expected_sbox[8'h0a] = 8'h67;
      expected_sbox[8'h0b] = 8'h2b;
      expected_sbox[8'h0c] = 8'hfe;
      expected_sbox[8'h0d] = 8'hd7;
      expected_sbox[8'h0e] = 8'hab;
      expected_sbox[8'h0f] = 8'h76;
      expected_sbox[8'h10] = 8'hca;
      expected_sbox[8'h11] = 8'h82;
      expected_sbox[8'h12] = 8'hc9;
      expected_sbox[8'h13] = 8'h7d;
      expected_sbox[8'h14] = 8'hfa;
      expected_sbox[8'h15] = 8'h59;
      expected_sbox[8'h16] = 8'h47;
      expected_sbox[8'h17] = 8'hf0;
      expected_sbox[8'h18] = 8'had;
      expected_sbox[8'h19] = 8'hd4;
      expected_sbox[8'h1a] = 8'ha2;
      expected_sbox[8'h1b] = 8'haf;
      expected_sbox[8'h1c] = 8'h9c;
      expected_sbox[8'h1d] = 8'ha4;
      expected_sbox[8'h1e] = 8'h72;
      expected_sbox[8'h1f] = 8'hc0;
      expected_sbox[8'h20] = 8'hb7;
      expected_sbox[8'h21] = 8'hfd;
      expected_sbox[8'h22] = 8'h93;
      expected_sbox[8'h23] = 8'h26;
      expected_sbox[8'h24] = 8'h36;
      expected_sbox[8'h25] = 8'h3f;
      expected_sbox[8'h26] = 8'hf7;
      expected_sbox[8'h27] = 8'hcc;
      expected_sbox[8'h28] = 8'h34;
      expected_sbox[8'h29] = 8'ha5;
      expected_sbox[8'h2a] = 8'he5;
      expected_sbox[8'h2b] = 8'hf1;
      expected_sbox[8'h2c] = 8'h71;
      expected_sbox[8'h2d] = 8'hd8;
      expected_sbox[8'h2e] = 8'h31;
      expected_sbox[8'h2f] = 8'h15;
      expected_sbox[8'h30] = 8'h04;
      expected_sbox[8'h31] = 8'hc7;
      expected_sbox[8'h32] = 8'h23;
      expected_sbox[8'h33] = 8'hc3;
      expected_sbox[8'h34] = 8'h18;
      expected_sbox[8'h35] = 8'h96;
      expected_sbox[8'h36] = 8'h05;
      expected_sbox[8'h37] = 8'h9a;
      expected_sbox[8'h38] = 8'h07;
      expected_sbox[8'h39] = 8'h12;
      expected_sbox[8'h3a] = 8'h80;
      expected_sbox[8'h3b] = 8'he2;
      expected_sbox[8'h3c] = 8'heb;
      expected_sbox[8'h3d] = 8'h27;
      expected_sbox[8'h3e] = 8'hb2;
      expected_sbox[8'h3f] = 8'h75;
      expected_sbox[8'h40] = 8'h09;
      expected_sbox[8'h41] = 8'h83;
      expected_sbox[8'h42] = 8'h2c;
      expected_sbox[8'h43] = 8'h1a;
      expected_sbox[8'h44] = 8'h1b;
      expected_sbox[8'h45] = 8'h6e;
      expected_sbox[8'h46] = 8'h5a;
      expected_sbox[8'h47] = 8'ha0;
      expected_sbox[8'h48] = 8'h52;
      expected_sbox[8'h49] = 8'h3b;
      expected_sbox[8'h4a] = 8'hd6;
      expected_sbox[8'h4b] = 8'hb3;
      expected_sbox[8'h4c] = 8'h29;
      expected_sbox[8'h4d] = 8'he3;
      expected_sbox[8'h4e] = 8'h2f;
      expected_sbox[8'h4f] = 8'h84;
      expected_sbox[8'h50] = 8'h53;
      expected_sbox[8'h51] = 8'hd1;
      expected_sbox[8'h52] = 8'h00;
      expected_sbox[8'h53] = 8'hed;
      expected_sbox[8'h54] = 8'h20;
      expected_sbox[8'h55] = 8'hfc;
      expected_sbox[8'h56] = 8'hb1;
      expected_sbox[8'h57] = 8'h5b;
      expected_sbox[8'h58] = 8'h6a;
      expected_sbox[8'h59] = 8'hcb;
      expected_sbox[8'h5a] = 8'hbe;
      expected_sbox[8'h5b] = 8'h39;
      expected_sbox[8'h5c] = 8'h4a;
      expected_sbox[8'h5d] = 8'h4c;
      expected_sbox[8'h5e] = 8'h58;
      expected_sbox[8'h5f] = 8'hcf;
      expected_sbox[8'h60] = 8'hd0;
      expected_sbox[8'h61] = 8'hef;
      expected_sbox[8'h62] = 8'haa;
      expected_sbox[8'h63] = 8'hfb;
      expected_sbox[8'h64] = 8'h43;
      expected_sbox[8'h65] = 8'h4d;
      expected_sbox[8'h66] = 8'h33;
      expected_sbox[8'h67] = 8'h85;
      expected_sbox[8'h68] = 8'h45;
      expected_sbox[8'h69] = 8'hf9;
      expected_sbox[8'h6a] = 8'h02;
      expected_sbox[8'h6b] = 8'h7f;
      expected_sbox[8'h6c] = 8'h50;
      expected_sbox[8'h6d] = 8'h3c;
      expected_sbox[8'h6e] = 8'h9f;
      expected_sbox[8'h6f] = 8'ha8;
      expected_sbox[8'h70] = 8'h51;
      expected_sbox[8'h71] = 8'ha3;
      expected_sbox[8'h72] = 8'h40;
      expected_sbox[8'h73] = 8'h8f;
      expected_sbox[8'h74] = 8'h92;
      expected_sbox[8'h75] = 8'h9d;
      expected_sbox[8'h76] = 8'h38;
      expected_sbox[8'h77] = 8'hf5;
      expected_sbox[8'h78] = 8'hbc;
      expected_sbox[8'h79] = 8'hb6;
      expected_sbox[8'h7a] = 8'hda;
      expected_sbox[8'h7b] = 8'h21;
      expected_sbox[8'h7c] = 8'h10;
      expected_sbox[8'h7d] = 8'hff;
      expected_sbox[8'h7e] = 8'hf3;
      expected_sbox[8'h7f] = 8'hd2;
      expected_sbox[8'h80] = 8'hcd;
      expected_sbox[8'h81] = 8'h0c;
      expected_sbox[8'h82] = 8'h13;
      expected_sbox[8'h83] = 8'hec;
      expected_sbox[8'h84] = 8'h5f;
      expected_sbox[8'h85] = 8'h97;
      expected_sbox[8'h86] = 8'h44;
      expected_sbox[8'h87] = 8'h17;
      expected_sbox[8'h88] = 8'hc4;
      expected_sbox[8'h89] = 8'ha7;
      expected_sbox[8'h8a] = 8'h7e;
      expected_sbox[8'h8b] = 8'h3d;
      expected_sbox[8'h8c] = 8'h64;
      expected_sbox[8'h8d] = 8'h5d;
      expected_sbox[8'h8e] = 8'h19;
      expected_sbox[8'h8f] = 8'h73;
      expected_sbox[8'h90] = 8'h60;
      expected_sbox[8'h91] = 8'h81;
      expected_sbox[8'h92] = 8'h4f;
      expected_sbox[8'h93] = 8'hdc;
      expected_sbox[8'h94] = 8'h22;
      expected_sbox[8'h95] = 8'h2a;
      expected_sbox[8'h96] = 8'h90;
      expected_sbox[8'h97] = 8'h88;
      expected_sbox[8'h98] = 8'h46;
      expected_sbox[8'h99] = 8'hee;
      expected_sbox[8'h9a] = 8'hb8;
      expected_sbox[8'h9b] = 8'h14;
      expected_sbox[8'h9c] = 8'hde;
      expected_sbox[8'h9d] = 8'h5e;
      expected_sbox[8'h9e] = 8'h0b;
      expected_sbox[8'h9f] = 8'hdb;
      expected_sbox[8'ha0] = 8'he0;
      expected_sbox[8'ha1] = 8'h32;
      expected_sbox[8'ha2] = 8'h3a;
      expected_sbox[8'ha3] = 8'h0a;
      expected_sbox[8'ha4] = 8'h49;
      expected_sbox[8'ha5] = 8'h06;
      expected_sbox[8'ha6] = 8'h24;
      expected_sbox[8'ha7] = 8'h5c;
      expected_sbox[8'ha8] = 8'hc2;
      expected_sbox[8'ha9] = 8'hd3;
      expected_sbox[8'haa] = 8'hac;
      expected_sbox[8'hab] = 8'h62;
      expected_sbox[8'hac] = 8'h91;
      expected_sbox[8'had] = 8'h95;
      expected_sbox[8'hae] = 8'he4;
      expected_sbox[8'haf] = 8'h79;
      expected_sbox[8'hb0] = 8'he7;
      expected_sbox[8'hb1] = 8'hc8;
      expected_sbox[8'hb2] = 8'h37;
      expected_sbox[8'hb3] = 8'h6d;
      expected_sbox[8'hb4] = 8'h8d;
      expected_sbox[8'hb5] = 8'hd5;
      expected_sbox[8'hb6] = 8'h4e;
      expected_sbox[8'hb7] = 8'ha9;
      expected_sbox[8'hb8] = 8'h6c;
      expected_sbox[8'hb9] = 8'h56;
      expected_sbox[8'hba] = 8'hf4;
      expected_sbox[8'hbb] = 8'hea;
      expected_sbox[8'hbc] = 8'h65;
      expected_sbox[8'hbd] = 8'h7a;
      expected_sbox[8'hbe] = 8'hae;
      expected_sbox[8'hbf] = 8'h08;
      expected_sbox[8'hc0] = 8'hba;
      expected_sbox[8'hc1] = 8'h78;
      expected_sbox[8'hc2] = 8'h25;
      expected_sbox[8'hc3] = 8'h2e;
      expected_sbox[8'hc4] = 8'h1c;
      expected_sbox[8'hc5] = 8'ha6;
      expected_sbox[8'hc6] = 8'hb4;
      expected_sbox[8'hc7] = 8'hc6;
      expected_sbox[8'hc8] = 8'he8;
      expected_sbox[8'hc9] = 8'hdd;
      expected_sbox[8'hca] = 8'h74;
      expected_sbox[8'hcb] = 8'h1f;
      expected_sbox[8'hcc] = 8'h4b;
      expected_sbox[8'hcd] = 8'hbd;
      expected_sbox[8'hce] = 8'h8b;
      expected_sbox[8'hcf] = 8'h8a;
      expected_sbox[8'hd0] = 8'h70;
      expected_sbox[8'hd1] = 8'h3e;
      expected_sbox[8'hd2] = 8'hb5;
      expected_sbox[8'hd3] = 8'h66;
      expected_sbox[8'hd4] = 8'h48;
      expected_sbox[8'hd5] = 8'h03;
      expected_sbox[8'hd6] = 8'hf6;
      expected_sbox[8'hd7] = 8'h0e;
      expected_sbox[8'hd8] = 8'h61;
      expected_sbox[8'hd9] = 8'h35;
      expected_sbox[8'hda] = 8'h57;
      expected_sbox[8'hdb] = 8'hb9;
      expected_sbox[8'hdc] = 8'h86;
      expected_sbox[8'hdd] = 8'hc1;
      expected_sbox[8'hde] = 8'h1d;
      expected_sbox[8'hdf] = 8'h9e;
      expected_sbox[8'he0] = 8'he1;
      expected_sbox[8'he1] = 8'hf8;
      expected_sbox[8'he2] = 8'h98;
      expected_sbox[8'he3] = 8'h11;
      expected_sbox[8'he4] = 8'h69;
      expected_sbox[8'he5] = 8'hd9;
      expected_sbox[8'he6] = 8'h8e;
      expected_sbox[8'he7] = 8'h94;
      expected_sbox[8'he8] = 8'h9b;
      expected_sbox[8'he9] = 8'h1e;
      expected_sbox[8'hea] = 8'h87;
      expected_sbox[8'heb] = 8'he9;
      expected_sbox[8'hec] = 8'hce;
      expected_sbox[8'hed] = 8'h55;
      expected_sbox[8'hee] = 8'h28;
      expected_sbox[8'hef] = 8'hdf;
      expected_sbox[8'hf0] = 8'h8c;
      expected_sbox[8'hf1] = 8'ha1;
      expected_sbox[8'hf2] = 8'h89;
      expected_sbox[8'hf3] = 8'h0d;
      expected_sbox[8'hf4] = 8'hbf;
      expected_sbox[8'hf5] = 8'he6;
      expected_sbox[8'hf6] = 8'h42;
      expected_sbox[8'hf7] = 8'h68;
      expected_sbox[8'hf8] = 8'h41;
      expected_sbox[8'hf9] = 8'h99;
      expected_sbox[8'hfa] = 8'h2d;
      expected_sbox[8'hfb] = 8'h0f;
      expected_sbox[8'hfc] = 8'hb0;
      expected_sbox[8'hfd] = 8'h54;
      expected_sbox[8'hfe] = 8'hbb;
      expected_sbox[8'hff] = 8'h16;
    end
  endtask // init_sbox_table

  //----------------------------------------------------------------
  // test_sbox
  //
  // Test all 256 S-box entries.
  //----------------------------------------------------------------
  task test_sbox;
    begin
      $display("Testing all 256 S-box entries...");
      
      for (i = 0; i < NUM_TESTS; i = i + 1) begin
        tb_sboxw = i[7:0];
        #1; // Allow combinational logic to settle
        
        if (tb_new_sboxw !== expected_sbox[i[7:0]]) begin
          $display("LOG: %0t : ERROR : tb_aes_sbox : dut.new_sboxw : expected_value: 8'h%02h actual_value: 8'h%02h", 
                   $time, expected_sbox[i[7:0]], tb_new_sboxw);
          errors = errors + 1;
        end
      end
      
      if (errors == 0) begin
        $display("LOG: %0t : INFO : tb_aes_sbox : all_sbox_entries : expected_value: PASS actual_value: PASS", $time);
      end else begin
        $display("LOG: %0t : ERROR : tb_aes_sbox : sbox_verification : expected_value: 0_errors actual_value: %0d_errors", $time, errors);
      end
    end
  endtask // test_sbox

  //----------------------------------------------------------------
  // Main test process.
  //----------------------------------------------------------------
  initial begin
    $display("TEST START");
    $display("===================================");
    $display("Testbench for AES S-box");
    $display("===================================");
    
    // Initialize
    errors = 0;
    tb_sboxw = 8'h00;
    
    // Load expected S-box values
    init_sbox_table();
    
    // Run tests
    #10;
    test_sbox();
    
    // Final result
    #10;
    $display("===================================");
    if (errors == 0) begin
      $display("TEST PASSED");
    end else begin
      $display("TEST FAILED");
      $display("Total errors: %0d", errors);
      $error("S-box verification failed with %0d errors", errors);
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

endmodule // tb_aes_sbox

//======================================================================
// EOF tb_aes_sbox.v
//======================================================================
