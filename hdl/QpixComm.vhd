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
--      qpixConf       : out QpixConfigType;
--      qpixReq        : out QpixRequestType;  

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
   signal txByteArr        : QpixByteArrType      := (others => (others => '0'));
   signal txByteValidArr   : std_logic_vector(3 downto 0) := (others => '0');
   signal txByteReadyArr   : std_logic_vector(3 downto 0) := (others => '0');

   signal RxByteArr        : QpixByteArrType      := (others => (others => '0'));
   signal RxByteValidArr   : std_logic_vector(3 downto 0) := (others => '0');

   signal RxFifoDoutArr    : QpixByteArrType      := (others => (others => '0'));
   signal RxFifoREnArr     : std_logic_vector(3 downto 0) := (others => '0');
   signal RxFifoEmptyArr   : std_logic_vector(3 downto 0) := (others => '0');
   signal RxFifoFullArr    : std_logic_vector(3 downto 0) := (others => '0');

   signal TxReadyOr        : std_logic := '0';

   --signal InData           : QpixDataFormatType := QpixDataZero_C;

begin
   
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
               -- inputs
               txByte      => TxByteArr(i), 
               txByteValid => TxByteValidArr(i), 
               txByteReady => TxByteReadyArr(i),
               -- outputs
               rxFrameErr  => open,
               rxBreakErr  => open,
               rxByte      => RxByteArr(i),
               rxByteValid => RxByteValidArr(i),
               -- external ports
               Rx          => RxPortsArr(i),
               Tx          => TxPortsArr(i)
			);

         -- select the correct RAM_TYPE
         gen_qdb_fifo: if (RAM_TYPE = "Lattice") generate
            FIFO_U : entity work.QDBFifo
            generic map(
               DATA_WIDTH => NUM_BITS_G,
               DEPTH      => 8,
               RAM_TYPE   => RAM_TYPE
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
         end generate;
         gen_fifo_cc: if (RAM_TYPE /= "Lattice") generate
            FIFO_U : entity work.fifo_cc
            generic map(
               DATA_WIDTH => NUM_BITS_G,
               DEPTH      => G_FIFO_MUX_DEPTH,
               RAM_TYPE   => RAM_TYPE
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
         end generate;

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

      inBytesArr        => RxFifoDoutArr,
      inFifoEmptyArr    => RxFifoEmptyArr,
      inFifoREnArr      => RxFifoREnArr,
      inData            => inData,
                        
      outData           => outData_i,
      outBytesArr       => TxByteArr,
      outBytesValidArr  => TxByteValidArr,
      txReady           => TxReady,

      -- FixMe / TODO??
      --qpixConf          => qpixConf,
      --qpixReq           => qpixReq,

      regData           => regData,
      regResp           => regResp
   );
   ------------------------------------------------------------

end behav;
