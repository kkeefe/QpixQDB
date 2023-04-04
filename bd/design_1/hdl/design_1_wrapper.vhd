--Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
--Date        : Mon Apr  3 17:47:25 2023
--Host        : Forerunner running 64-bit major release  (build 9200)
--Command     : generate_target design_1_wrapper.bd
--Design      : design_1_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity design_1_wrapper is
  port (
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    FCLK : out STD_LOGIC;
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    M_AXI_0_araddr : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_arprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    M_AXI_0_arready : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_arvalid : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_awaddr : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_awprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    M_AXI_0_awready : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_awvalid : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_bready : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_bresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    M_AXI_0_bvalid : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_rdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_rready : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    M_AXI_0_rvalid : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_wdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_wready : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_wstrb : out STD_LOGIC_VECTOR ( 3 downto 0 );
    M_AXI_0_wvalid : out STD_LOGIC_VECTOR ( 0 to 0 );
    S_AXIS_0_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXIS_0_tkeep : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXIS_0_tlast : in STD_LOGIC;
    S_AXIS_0_tready : out STD_LOGIC;
    S_AXIS_0_tvalid : in STD_LOGIC;
    aresetn : out STD_LOGIC_VECTOR ( 0 to 0 );
    clk_out1_0 : out STD_LOGIC;
    clk_out2_0 : out STD_LOGIC;
    locked_0 : out STD_LOGIC;
    reset_rtl : in STD_LOGIC;
    reset_rtl_0 : in STD_LOGIC;
    sys_clock : in STD_LOGIC
  );
end design_1_wrapper;

architecture STRUCTURE of design_1_wrapper is
  component design_1 is
  port (
    reset_rtl : in STD_LOGIC;
    FCLK : out STD_LOGIC;
    aresetn : out STD_LOGIC_VECTOR ( 0 to 0 );
    reset_rtl_0 : in STD_LOGIC;
    sys_clock : in STD_LOGIC;
    clk_out1_0 : out STD_LOGIC;
    locked_0 : out STD_LOGIC;
    clk_out2_0 : out STD_LOGIC;
    M_AXI_0_awaddr : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_awprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    M_AXI_0_awvalid : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_awready : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_wdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_wstrb : out STD_LOGIC_VECTOR ( 3 downto 0 );
    M_AXI_0_wvalid : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_wready : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_bresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    M_AXI_0_bvalid : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_bready : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_araddr : out STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_arprot : out STD_LOGIC_VECTOR ( 2 downto 0 );
    M_AXI_0_arvalid : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_arready : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_rdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    M_AXI_0_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    M_AXI_0_rvalid : in STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXI_0_rready : out STD_LOGIC_VECTOR ( 0 to 0 );
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    DDR_cas_n : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXIS_0_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXIS_0_tkeep : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXIS_0_tlast : in STD_LOGIC;
    S_AXIS_0_tready : out STD_LOGIC;
    S_AXIS_0_tvalid : in STD_LOGIC
  );
  end component design_1;
begin
design_1_i: component design_1
     port map (
      DDR_addr(14 downto 0) => DDR_addr(14 downto 0),
      DDR_ba(2 downto 0) => DDR_ba(2 downto 0),
      DDR_cas_n => DDR_cas_n,
      DDR_ck_n => DDR_ck_n,
      DDR_ck_p => DDR_ck_p,
      DDR_cke => DDR_cke,
      DDR_cs_n => DDR_cs_n,
      DDR_dm(3 downto 0) => DDR_dm(3 downto 0),
      DDR_dq(31 downto 0) => DDR_dq(31 downto 0),
      DDR_dqs_n(3 downto 0) => DDR_dqs_n(3 downto 0),
      DDR_dqs_p(3 downto 0) => DDR_dqs_p(3 downto 0),
      DDR_odt => DDR_odt,
      DDR_ras_n => DDR_ras_n,
      DDR_reset_n => DDR_reset_n,
      DDR_we_n => DDR_we_n,
      FCLK => FCLK,
      FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
      FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
      FIXED_IO_mio(53 downto 0) => FIXED_IO_mio(53 downto 0),
      FIXED_IO_ps_clk => FIXED_IO_ps_clk,
      FIXED_IO_ps_porb => FIXED_IO_ps_porb,
      FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
      M_AXI_0_araddr(31 downto 0) => M_AXI_0_araddr(31 downto 0),
      M_AXI_0_arprot(2 downto 0) => M_AXI_0_arprot(2 downto 0),
      M_AXI_0_arready(0) => M_AXI_0_arready(0),
      M_AXI_0_arvalid(0) => M_AXI_0_arvalid(0),
      M_AXI_0_awaddr(31 downto 0) => M_AXI_0_awaddr(31 downto 0),
      M_AXI_0_awprot(2 downto 0) => M_AXI_0_awprot(2 downto 0),
      M_AXI_0_awready(0) => M_AXI_0_awready(0),
      M_AXI_0_awvalid(0) => M_AXI_0_awvalid(0),
      M_AXI_0_bready(0) => M_AXI_0_bready(0),
      M_AXI_0_bresp(1 downto 0) => M_AXI_0_bresp(1 downto 0),
      M_AXI_0_bvalid(0) => M_AXI_0_bvalid(0),
      M_AXI_0_rdata(31 downto 0) => M_AXI_0_rdata(31 downto 0),
      M_AXI_0_rready(0) => M_AXI_0_rready(0),
      M_AXI_0_rresp(1 downto 0) => M_AXI_0_rresp(1 downto 0),
      M_AXI_0_rvalid(0) => M_AXI_0_rvalid(0),
      M_AXI_0_wdata(31 downto 0) => M_AXI_0_wdata(31 downto 0),
      M_AXI_0_wready(0) => M_AXI_0_wready(0),
      M_AXI_0_wstrb(3 downto 0) => M_AXI_0_wstrb(3 downto 0),
      M_AXI_0_wvalid(0) => M_AXI_0_wvalid(0),
      S_AXIS_0_tdata(31 downto 0) => S_AXIS_0_tdata(31 downto 0),
      S_AXIS_0_tkeep(3 downto 0) => S_AXIS_0_tkeep(3 downto 0),
      S_AXIS_0_tlast => S_AXIS_0_tlast,
      S_AXIS_0_tready => S_AXIS_0_tready,
      S_AXIS_0_tvalid => S_AXIS_0_tvalid,
      aresetn(0) => aresetn(0),
      clk_out1_0 => clk_out1_0,
      clk_out2_0 => clk_out2_0,
      locked_0 => locked_0,
      reset_rtl => reset_rtl,
      reset_rtl_0 => reset_rtl_0,
      sys_clock => sys_clock
    );
end STRUCTURE;
