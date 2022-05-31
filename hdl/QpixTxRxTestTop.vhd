library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.QpixPkg.all;
use work.QpixProtoPkg.all;

entity QpixTxRxTestTop is
   generic (
      BOARD_G : string  := "ZYBO"; -- ZYBO, MINIZED, PYNQ
      TXRX_TYPE : string  := "ENDEAVOR"; -- "DUMMY"/"UART"/"ENDEAVOR"
      X_NUM_G : natural := 3;
      Y_NUM_G : natural := 3 
      
   );
   port (
      sysClk    : in std_logic;
      led       : out std_logic_vector(3 downto 0);
      sw        : in  std_logic_vector(3 downto 0);
      je        : out std_logic_vector(1 downto 0);
      DaqTx     : out std_logic;
      DaqRx     : in  std_logic;
      -- led_5
      led5_r : out std_logic;
      led5_b : out std_logic;
      led5_g : out std_logic;

      -- led_6
--      led6_r : out std_logic;
--      led6_b : out std_logic;
--      led6_g : out std_logic;

      -- PS ports
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
      FIXED_IO_ddr_vrn : inout STD_LOGIC;
      FIXED_IO_ddr_vrp : inout STD_LOGIC;
      FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
      FIXED_IO_ps_clk : inout STD_LOGIC;
      FIXED_IO_ps_porb : inout STD_LOGIC;
      FIXED_IO_ps_srstb : inout STD_LOGIC
      
   );
end entity QpixTxRxTestTop;

architecture behav of QpixTxRxTestTop is

   signal fclk : std_logic;
   signal clk  : std_logic := '0';
   signal rst  : std_logic := '0';

    -- ps-pl axi
   signal axi_resetn  : std_logic_vector(0 downto 0) := (others => '1');
   signal axi_awaddr  : std_logic_vector ( 31 downto 0 );
   signal axi_awprot  : std_logic_vector ( 2 downto 0 );
   signal axi_awvalid : std_logic;
   signal axi_awready : std_logic;
   signal axi_wdata   : std_logic_vector ( 31 downto 0 );
   signal axi_wstrb   : std_logic_vector ( 3 downto 0 );
   signal axi_wvalid  : std_logic;
   signal axi_wready  : std_logic;
   signal axi_bresp   : std_logic_vector ( 1 downto 0 );
   signal axi_bvalid  : std_logic;
   signal axi_bready  : std_logic;
   signal axi_araddr  : std_logic_vector ( 31 downto 0 );
   signal axi_arprot  : std_logic_vector ( 2 downto 0 );
   signal axi_arvalid : std_logic;
   signal axi_arready : std_logic;
   signal axi_rdata   : std_logic_vector ( 31 downto 0 );
   signal axi_rresp   : std_logic_vector ( 1 downto 0 );
   signal axi_rvalid  : std_logic;
   signal axi_rready  : std_logic;

   signal reg_addr    : std_logic_vector (31 downto 0);
   signal reg_rdata   : std_logic_vector (31 downto 0);
   signal reg_wdata   : std_logic_vector (31 downto 0);
   signal reg_req     : std_logic := '0';
   signal reg_wen     : std_logic := '0';
   signal reg_ack     : std_logic := '0';

   --signal daqTx       : QpixTxRxPortType := QpixTxRxPortZero_C;
   --signal daqRx       : QpixTxRxPortType := QpixTxRxPortZero_C;

   signal TxPortsArr  : QpixTxRxPortsArrType;
   signal RxPortsArr  : QpixTxRxPortsArrType;

   signal hitMask     : Sl2DArray := (others => (others => '0')) ;

   signal trg         : std_logic := '0';
   signal asicAddr    : std_logic_vector(31 downto 0) := (others => '0');
   signal asicOpWrite : std_logic := '0';
   signal asicData    : std_logic_vector(15 downto 0);
   signal asicReq     : std_logic := '0';
   --signal hitXY       : std_logic_vector (31 downto 0) := (others => '0');
   signal timestamp    : std_logic_vector (G_TIMESTAMP_BITS-1 downto 0) := (others => '0');
   signal chanMask     : std_logic_vector (G_N_ANALOG_CHAN-1 downto 0)  := (others => '0');
   signal trgTime      : std_logic_vector (31 downto 0) := (others => '0');

   signal evtSize     : std_logic_vector (31 downto 0) := (others => '0');

   signal memAddrRst  : std_logic := '0';
   signal memRdAddr   : std_logic_vector (G_QPIX_PROTO_MEM_DEPTH-1+2 downto 0) := (others => '0');
   signal memDataOut  : std_logic_vector (31 downto 0) := (others => '0');
   signal memRdAck    : std_logic := '0';
   signal memRdReq    : std_logic := '0';
   signal memEvtSize  : std_logic_vector (G_QPIX_PROTO_MEM_DEPTH-1 downto 0) := (others => '0');

   signal leds        : std_logic_vector(3 downto 0) := (others => '0');

   signal qpixDebugArr : QpixDebug2DArrayType(0 to X_NUM_G-1, 0 to Y_NUM_G-1);

   signal extFifoMaxArr : Slv4b2DArray;

   signal status      : std_logic_vector(31 downto 0) := (others => '0');

   signal asic_mask   : std_logic_vector (15 downto 0) ;

   signal qClk        : std_logic := '0';

   signal daqFrameErrCnt : std_logic_vector (31 downto 0) := (others => '0');
   signal daqBreakErrCnt : std_logic_vector (31 downto 0) := (others => '0');

   signal daqTestWordOut : std_logic_vector(G_DATA_BITS-1 downto 0);
   signal daqTestWordIn  : std_logic_vector(G_DATA_BITS-1 downto 0);
   
   -- buffer daqTx / daqRx
   signal s_daqTx : std_logic := '0';
   signal s_daqRx : std_logic := '0';
   signal pulse_tx : std_logic := '0';
   signal pulse_rx : std_logic := '0';
   constant pulse_time : integer := 12_999_999; -- fclk_freq / pulse_time = pulse's width
   
--   signal pulse_state : std_logic := '0';
   signal pulse_rxbv : std_logic := '0';
   signal pulse_txbv : std_logic := '0';

    signal pulse_red : std_logic := '0';
    signal pulse_blu : std_logic := '0';
    signal pulse_gre : std_logic := '0';
    -- signal led_state : std_logic_vector(1 downto 0) := "00";
    
    signal state_o : std_logic := '0';
    signal txByteValid_o : std_logic := '0';
    signal rxByteValid_o : std_logic := '0';



begin

led <= sw;
je  <= sw(1 downto 0);
s_daqRx <= daqRx;
daqTx <= s_daqTx;

-- LED-5, active high 
led5_r <= pulse_red;
led5_b <= pulse_blu;
led5_g <= pulse_gre;


-- LED-6 
--led6_r <= led_state(0); -- red when Rx
--led6_b <= led_state(1); -- blu when Tx
--with state_o select led_state <=
-- "01" when '0',
-- "10" when '1';
--led6_g <= pulse_txbv or pulse_rxbv;


   ---------------------------------------------------
   -- Processing system
   ---------------------------------------------------
      design_1_U : entity work.design_1_wrapper
         port map (
            -- PS ports
            DDR_addr(14 downto 0)     => DDR_addr(14 downto 0),
            DDR_ba(2 downto 0)        => DDR_ba(2 downto 0),
            DDR_cas_n                 => DDR_cas_n,
            DDR_ck_n                  => DDR_ck_n,
            DDR_ck_p                  => DDR_ck_p,
            DDR_cke                   => DDR_cke,
            DDR_cs_n                  => DDR_cs_n,
            DDR_dm(3 downto 0)        => DDR_dm(3 downto 0),
            DDR_dq(31 downto 0)       => DDR_dq(31 downto 0),
            DDR_dqs_n(3 downto 0)     => DDR_dqs_n(3 downto 0),
            DDR_dqs_p(3 downto 0)     => DDR_dqs_p(3 downto 0),
            DDR_odt                   => DDR_odt,
            DDR_ras_n                 => DDR_ras_n,
            DDR_reset_n               => DDR_reset_n,
            DDR_we_n                  => DDR_we_n,
            FIXED_IO_ddr_vrn          => FIXED_IO_ddr_vrn,
            FIXED_IO_ddr_vrp          => FIXED_IO_ddr_vrp,
            FIXED_IO_mio(53 downto 0) => FIXED_IO_mio(53 downto 0),
            FIXED_IO_ps_clk           => FIXED_IO_ps_clk,
            FIXED_IO_ps_porb          => FIXED_IO_ps_porb,
            FIXED_IO_ps_srstb         => FIXED_IO_ps_srstb,

            reset_rtl                 => '0',
            -- axi interface to PL
            M_AXI_0_awaddr            => axi_awaddr,
            M_AXI_0_awprot            => axi_awprot, 
            M_AXI_0_awvalid           => axi_awvalid,
            M_AXI_0_awready           => axi_awready,
            M_AXI_0_wdata             => axi_wdata,  
            M_AXI_0_wstrb             => axi_wstrb,  
            M_AXI_0_wvalid            => axi_wvalid, 
            M_AXI_0_wready            => axi_wready, 
            M_AXI_0_bresp             => axi_bresp,  
            M_AXI_0_bvalid            => axi_bvalid, 
            M_AXI_0_bready            => axi_bready, 
            M_AXI_0_araddr            => axi_araddr, 
            M_AXI_0_arprot            => axi_arprot, 
            M_AXI_0_arvalid           => axi_arvalid,
            M_AXI_0_arready           => axi_arready,
            M_AXI_0_rdata             => axi_rdata,  
            M_AXI_0_rresp             => axi_rresp,  
            M_AXI_0_rvalid            => axi_rvalid, 
            M_AXI_0_rready            => axi_rready, 
            aresetn                   => axi_resetn,
            fclk                      => fclk, 

            -- CLK Wizard
            reset_rtl_0               => '0',
            sys_clock                 => sysClk,
            clk_out1_0                => open,            
            clk_out2_0                => clk,
            locked_0                  => open
         );

   ---------------------------------------------------
   -- AXI Lite interface
   ---------------------------------------------------
   AxiLiteSlaveSimple_U : entity work.AxiLiteSlaveSimple
      port map(
         axi_aclk              => fclk,
         axi_aresetn           => axi_resetn(0),

         axi_awaddr            => axi_awaddr,
         axi_awprot            => axi_awprot, 
         axi_awvalid           => axi_awvalid,
         axi_awready           => axi_awready,
         axi_wdata             => axi_wdata,  
         axi_wstrb             => axi_wstrb,  
         axi_wvalid            => axi_wvalid, 
         axi_wready            => axi_wready, 
         axi_bresp             => axi_bresp,  
         axi_bvalid            => axi_bvalid, 
         axi_bready            => axi_bready, 
         axi_araddr            => axi_araddr, 
         axi_arprot            => axi_arprot, 
         axi_arvalid           => axi_arvalid,
         axi_arready           => axi_arready,
         axi_rdata             => axi_rdata,  
         axi_rresp             => axi_rresp,  
         axi_rvalid            => axi_rvalid, 
         axi_rready            => axi_rready, 

         addr                  => reg_addr, 
         rdata                 => reg_rdata,
         wdata                 => reg_wdata,
         req                   => reg_req,
         wen                   => reg_wen,
         ack                   => reg_ack
      );
   ---------------------------------------------------

   ---------------------------------------------------
   ---------------------------------------------------
   QpixProtoRegMap_U : entity work.QpixProtoRegMap
   generic map (
      X_NUM_G => X_NUM_G,
      Y_NUM_G => Y_NUM_G,
      Version => x"0000_0001"
   )
   port map(
      clk          => fclk,
      rst          => rst,
                   
      addr         => reg_addr,
      rdata        => reg_rdata,
      wdata        => reg_wdata,
      req          => reg_req,
      wen          => reg_wen,
      ack          => reg_ack,

      asic_mask    => asic_mask,

      evtSize      => evtSize,
      status       => status,
      extFifoMax   => extFifoMaxArr,

      daqFrameErrCnt => daqFrameErrCnt,
      daqBreakErrCnt => daqBreakErrCnt,

      trgTime      => trgTime,
      timestamp    => timestamp,
      hitMask      => hitMask,
      chanMask     => chanMask,
                  
      trg          => trg,
      asicAddr     => asicAddr,
      asicOpWrite  => asicOpWrite,
      asicData     => asicData,
      asicReq      => asicReq,

      memRdReq     => memRdReq,
      memRdAck     => memRdAck,
      memData      => memDataOut,
      memAddr      => memRdAddr,

      daqTestWordOut => daqTestWordOut,
      daqTestWordIn  => daqTestWordIn
   );
   ---------------------------------------------------

   -----------------------------------------------------
   ---- DAQ node
   -----------------------------------------------------
   QpixDaqCtrl_U : entity work.QpixDaqCtrlDummy
   port map(
      clk         => fclk,
      rst         => rst,
                  
      daqTx       => s_daqTx, -- output
      daqRx       => s_daqRx, -- input

      sndWord     => daqTestWordOut,
      recWord     => daqTestWordIn,

      trg         => trg,
      busy        => status(0)
   );
   memAddrRst <= trg or asicReq;
   ---------------------------------------------------

 pulse : process (fclk, s_daqRx, s_daqTx, state_o, txByteValid_o, rxByteValid_o) is
     variable pulse_count_red : integer range 0 to pulse_time := 0;
     variable start_pulse_red : std_logic := '0';
     variable pulse_count_blu : integer range 0 to pulse_time := 0;
     variable start_pulse_blu : std_logic := '0';
     variable pulse_count_gre : integer range 0 to pulse_time := 0;
     variable start_pulse_gre : std_logic := '0';

 begin
     if rising_edge(fclk) then

         -- pulse red
         if sw(2) = '1' then
             start_pulse_red := '1';
             pulse_count_red := 0;
         end if;
         if start_pulse_red = '1' then
             pulse_count_red := pulse_count_red + 1;
             pulse_red <= '1';
             if pulse_count_red >= pulse_time then
                 pulse_red       <= '0';
                 pulse_count_red := 0;
                 start_pulse_red := '0';
             end if;
         end if;
         
         -- pulse blue 
         if s_daqTx = '1' then
             start_pulse_blu := '1';
             pulse_count_blu := 0;
         end if;
         if start_pulse_blu = '1' then
             pulse_count_blu := pulse_count_blu + 1;
             pulse_blu <= '1';
             if pulse_count_blu >= pulse_time then
                 pulse_blu       <= '0';
                 pulse_count_blu := 0;
                 start_pulse_blu := '0';
             end if;
         end if;

        -- pulse green
        if s_daqRx = '1' then
            start_pulse_gre := '1';
            pulse_count_gre := 0;
        end if;
        if start_pulse_gre = '1' then
            pulse_count_gre := pulse_count_gre + 1;
            pulse_gre <= '1';
            if pulse_count_gre >= pulse_time then
                pulse_gre       <= '0';
                pulse_count_gre := 0;
                start_pulse_gre := '0';
            end if;
        end if;
 
     end if;
 end process pulse;

--   RxPortsArr(0) <= daqTx;
--   daqRx <= TxPortsArr(0);

--   QpixAsicDummyTop_u1 : entity work.QpixAsicDummyTop
--   port map (
--      clk      => fclk,
----      rst             => '0',
--      -- TX ports to neighbour ASICs
--      Tx3      => s_daqRx,
--      -- RX ports to neighbour ASICs
--      Rx3      => s_daqTx,
--      -- outputs
--      state_o       => state_o, -- which state is the machine in
--      rxByteValid_o => rxByteValid_o,
--      txByteValid_o => txByteValid_o,
--      -- leds
--      red_led => red_led, -- lenError
--      gre_led => gre_led, -- GapError
--      blu_led => blu_led  -- bitError
--   );
   
end behav;
