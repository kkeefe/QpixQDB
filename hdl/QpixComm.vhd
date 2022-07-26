----------------------------------------------------------------------------------
-- QPix communication with neighbour ASICs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library work;
use work.QpixPkg.all;


entity QpixComm is
   generic (
      NUM_BITS_G     : natural := 64;
      GATE_DELAY_G   : time    := 1 ns;
      X_POS_G        : natural := 0;
      Y_POS_G        : natural := 0;
      RAM_TYPE       : string  := "Lattice"; -- lattice hardcodes BRAM for lattice, or distributed / block
      TXRX_TYPE      : string  := "UART" -- "DUMMY"/"UART"/"ENDEAVOR"
   );
   port (
      clk            : in std_logic;
      rst            : in std_logic;

      -- external ASIC ports
      TxPortsArr     : out std_logic_vector(3 downto 0);
      RxPortsArr     : in  std_logic_vector(3 downto 0);
      
      -- tx/rx data to QpixRoute
      outData_i      : in  QpixDataFormatType; -- Tx from QpixRoute
      inData         : out QpixDataFormatType; -- Rx to QpixRoute
      TxReady        : out std_logic;          -- Tx-ready to QpixRoute

      -- -- Fixme / TODO?? - These ports do nothing in QpixParser.vhd
      -- register info to QpixRoute
      qpixConf       : in QpixConfigType;
--      qpixReq        : out QpixRequestType;

      -- Debug
      TxByteValidArr_out : out std_logic_vector(3 downto 0);
      RxByteValidArr_out : out std_logic_vector(3 downto 0);
      RxFifoEmptyArr_out : out std_logic_vector(3 downto 0);
      RxFifoFullArr_out  : out std_logic_vector(3 downto 0);

      -- register information to QpixRegFile
      regData        : out QpixRegDataType;
      regResp        : in QpixRegDataType
   );
end entity QpixComm;

architecture behav of QpixComm is

   ------------------------------------------------------------
   -- Type defenitions
   ------------------------------------------------------------
   type QpixDataArrType is array (0 to 3) of QpixDataFormatType;

   ------------------------------------------------------------
   -- Signals
   ------------------------------------------------------------
   signal TxByteArr      : QpixByteArrType              := (others => (others => '0'));
   signal TxByteValidArr : std_logic_vector(3 downto 0) := (others => '0');
   signal TxByteReadyArr : std_logic_vector(3 downto 0) := (others => '0');

   signal RxByteArr        : QpixByteArrType      := (others => (others => '0'));
   signal RxByteValidArr   : std_logic_vector(3 downto 0) := (others => '0');

   signal RxFifoDoutArr    : QpixByteArrType      := (others => (others => '0'));
   signal RxFifoREnArr     : std_logic_vector(3 downto 0) := (others => '0');
   signal RxFifoEmptyArr   : std_logic_vector(3 downto 0) := (others => '0');
   signal RxFifoFullArr    : std_logic_vector(3 downto 0) := (others => '0');

   signal TxReadyOr        : std_logic := '0';

   --signal InData           : QpixDataFormatType := QpixDataZero_C;

begin

   -- debug
   TxByteValidArr_out <= TxByteValidArr;
   RxByteValidArr_out <= RxByteValidArr;
   RxFifoEmptyArr_out <= RxFifoEmptyArr;
   RxFifoFullArr_out <= RxFifoFullArr;
   
   ------------------------------------------------------------
   -- Transcievers
   ------------------------------------------------------------
   GEN_TXRX : for i in 0 to 3 generate
         QpixTXRx_U : entity work.QpixEndeavorTop
        generic map (
         NUM_BITS_G => NUM_BITS_G
         )
          port map (
               clk         => clk,
               sRst        => rst,
               -- Input of TxByte to send to physical
               txByte      => TxByteArr(i),       -- input, slv(63 downto 0)
               txByteValid => TxByteValidArr(i),  -- input
               txByteReady => TxByteReadyArr(i),  -- ouput
               -- Output of Rx to FIFO
               rxFrameErr  => open,               -- output
               rxBreakErr  => open,               -- output
               rxGapErr    => open,               -- output
               rxByte      => RxByteArr(i),       -- output, slv(63 downto 0)
               rxByteValid => RxByteValidArr(i),  -- output
               rxState     => open,               -- output, slv(2 downto 0)
               -- external ports
               Rx          => RxPortsArr(i),      -- input
               Tx          => TxPortsArr(i)       -- output
         );

         -- select the correct RAM_TYPE
         --gen_qdb_fifo: if (RAM_TYPE = "Lattice") generate
            --FIFO_U : entity work.QDBFifo
            --generic map(
               --DATA_WIDTH => NUM_BITS_G,
               --DEPTH      => G_FIFO_MUX_DEPTH,
               --RAM_TYPE   => RAM_TYPE
            --)
            --port map(
               --clk   => clk,
               --rst   => rst,
               --din   => RxByteArr(i),
               --wen   => RxByteValidArr(i),
               --ren   => RxFifoREnArr(i),
               --dout  => RxFifoDoutArr(i),
               --empty => RxFifoEmptyArr(i),
               --full  => RxFifoFullArr(i)
            --);
         --end generate;
         --gen_fifo_cc: if (RAM_TYPE /= "Lattice") generate
            FIFO_U : entity work.fifo_cc
            generic map(
               DATA_WIDTH => NUM_BITS_G,
               DEPTH      => 8,
               RAM_TYPE   => "distributed"
            )
            port map(
               clk   => clk,
               rst   => rst,
               din   => RxByteArr(i),
               wen   => RxByteValidArr(i),
               ren   => RxFifoREnArr(i),
               dout  => RxFifoDoutArr(i),
               empty => RxFifoEmptyArr(i),
               full  => RxFifoFullArr(i)
            );
         --end generate;

   end generate GEN_TXRX;
   ------------------------------------------------------------

   TxReadyOr <= '1' when TxByteReadyArr = "1111" else '0';
   TxReady   <= TxReadyOr;

   ------------------------------------------------------------
   -- Parser
   ------------------------------------------------------------
   QpixParser_U : entity work.QpixParser
   generic map(
      X_POS_G       => X_POS_G,
      Y_POS_G       => Y_POS_G
   )                
   port map(
      clk          => clk,
      rst          => rst,

      -- FIFO data from the Rx port
      inBytesArr     => RxFifoDoutArr,   -- input
      inFifoEmptyArr => RxFifoEmptyArr,  -- input
      inFifoREnArr   => RxFifoREnArr,    -- output

      -- Tx Endeavor connections
      outBytesArr      => TxByteArr,       -- output
      outBytesValidArr => TxByteValidArr,  -- output
      txReady          => TxReady,         -- input

      -- data to route
      inData  => inData,                -- output
      outData => outData_i,             -- input

      -- regFile configurations
      -- FixMe / TODO??
      qpixConf => qpixConf,             -- input
      --qpixReq           => qpixReq,
      regData => regData,               -- output
      regResp => regResp                -- input
   );
   ------------------------------------------------------------

end behav;
