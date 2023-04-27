----------------------------------------------------------------------------------
-- QPix routing module
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.QpixPkg.all;

entity QpixRoute is
   generic (
      GATE_DELAY_G    : time    := 1 ns;
      RAM_TYPE        : string  := "Lattice"; -- lattice hardcodes BRAM for lattice, or distributed / block
      X_POS_G         : natural := 0;
      Y_POS_G         : natural := 0
   );
   port (
      clk             : in std_logic;
      rst             : in std_logic;
      
      -- Register information from QpixRegFile
      clkCnt          : in  std_logic_vector(31 downto 0);
      qpixReq         : in  QpixRequestType;
      qpixConf        : in  QpixConfigType;
      
      -- Tx/Rx data to QpixComm -> QPixParser
      txReady         : in  std_logic;
      txData          : out QpixDataFormatType;
      rxData          : in  QpixDataFormatType;

      -- QpixDataProc data and enable
      inData          : in  QpixDataFormatType;

      busy            : out std_logic;
      intrNum         : out std_logic_vector(15 downto 0);
      extFifoFull     : out std_logic;
      locFifoFull     : out std_logic;
      extFifoEmpty    : out std_logic;
      locFifoEmpty    : out std_logic;
      fsmState        : out std_logic_vector(2 downto 0)
                      
   );
end entity QpixRoute;

architecture behav of QpixRoute is

   type RouteStatesType is (IDLE_S, REP_LOCAL_S, REP_REMOTE_S, REP_FINISH_S);

   ---------------------------------------------------
   -- Types defenitions
   ---------------------------------------------------
   type RegType is record
      state        :  RouteStatesType;
      stateCnt     :  unsigned(G_REG_DATA_BITS-1 downto 0);
      --timeout      :  unsigned(qpixConf.Timeout'range);
      intTime      :  std_logic_vector(31 downto 0);
      reqID        :  std_logic_vector(3 downto 0);
      txData       :  QpixDataFormatType;
      respDir      :  std_logic_vector(3 downto 0);
      manRoute     :  std_logic;
      locFifoRen   :  std_logic;
      extFifoRen   :  std_logic;
      -- softInterr   :  std_logic;
      intrNum      :  unsigned(15 downto 0);
      extFull      :  std_logic;
      locFull      :  std_logic;
   end record;
   ---------------------------------------------------

   ---------------------------------------------------
   -- Constants
   ---------------------------------------------------
   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      stateCnt     => (others => '0'),
      --timeout      => (others => '0'),
      intTime      => (others => '0'),
      reqID        => (others => '0'),
      txData       => QpixDataZero_C,
      respDir      => (others => '0'),
      manRoute     => '0',
      locFifoRen   => '0',
      extFifoRen   => '0',
      -- softInterr   => '0',
      intrNum      => (others => '0'),
      extFull      => '0',
      locFull      => '0'
   );
   ---------------------------------------------------

   ---------------------------------------------------
   -- Signals
   ---------------------------------------------------
   signal curReg : RegType := REG_INIT_C;
   signal nxtReg : RegType := REG_INIT_C;

   signal s_locFifoEmpty   : std_logic := '0';
   signal locFifoDin     : std_logic_vector (G_N_ANALOG_CHAN+G_TIMESTAMP_BITS-1 downto 0);
   signal locFifoDout    : std_logic_vector (G_N_ANALOG_CHAN+G_TIMESTAMP_BITS-1 downto 0);
   signal locFull        : std_logic := '0';

   signal s_extFifoEmpty   : std_logic := '0';
   signal extFifoRen     : std_logic := '0';
   signal extFifoDout    : std_logic_vector (G_DATA_BITS-1 downto 0);
   signal extFull        : std_logic := '0';
   -- signal respDir        : std_logic_vector(3 downto 0) := (others => '0');

   ---------------------------------------------------

begin

   extFifoEmpty <= s_extFifoEmpty;
   locFifoEmpty <= s_locFifoEmpty;

   ---------------------------------------------------
   -- FIFO for local data
   ---------------------------------------------------
   gen_qdb_fifo_loc: if (RAM_TYPE = "Lattice") generate
      FIFO_LOC_U : entity work.QDBFifo
      generic map(
         DATA_WIDTH => G_N_ANALOG_CHAN + G_TIMESTAMP_BITS, -- 16 + 32 = 48
         DEPTH      => 9,
         RAM_TYPE   => "Lattice_fifo_loc"
      )
      port map(
         clk   => clk,
         rst   => rst,
         din   => locFifoDin,
         wen   => inData.DataValid,
         ren   => curReg.locFifoRen,
         dout  => locFifoDout,
         empty => s_locFifoEmpty,
         full  => locFull
      );
   end generate;
   gen_fifo_loc: if (RAM_TYPE /= "Lattice") generate
      FIFO_LOC_U : entity work.fifo_cc
      generic map(
         DATA_WIDTH => G_N_ANALOG_CHAN + G_TIMESTAMP_BITS,
         DEPTH      => G_FIFO_LOC_DEPTH,
         RAM_TYPE   => "block"
      )
      port map(
         clk   => clk,
         rst   => rst,
         din   => locFifoDin,
         wen   => inData.DataValid,
         ren   => curReg.locFifoRen,
         dout  => locFifoDout,
         empty => s_locFifoEmpty,
         full  => locFull
      );
   end generate;
   locFifoDin <= inData.ChanMask & inData.Timestamp;
   ---------------------------------------------------

   ---------------------------------------------------
   -- FIFO for external data
   ---------------------------------------------------
   gen_qdb_fifo_ext: if (RAM_TYPE = "Lattice") generate
      FIFO_EXT_U : entity work.QDBFifo
      generic map(
         DATA_WIDTH => G_DATA_BITS, -- 64
         DEPTH      => 9,
         RAM_TYPE   => "Lattice_fifo_ext"
      )
      port map(
         clk   => clk,
         rst   => rst,
         din   => rxData.Data,
         wen   => rxData.DataValid,
         ren   => curReg.extFifoRen,
         dout  => extFifoDout,
         empty => s_extFifoEmpty,
         full  => extFull
      );
   end generate;
   gen_fifo_ext: if (RAM_TYPE /= "Lattice") generate
   FIFO_EXT_U : entity work.fifo_cc
   generic map(
      DATA_WIDTH => G_DATA_BITS,
      DEPTH      => G_FIFO_EXT_DEPTH,
      RAM_TYPE   => "distributed"
   )
   port map(
      clk   => clk,
      rst   => rst,
      din   => rxData.Data,
      wen   => rxData.DataValid,
      ren   => curReg.extFifoRen,
      dout  => extFifoDout, 
      empty => s_extFifoEmpty,
      full  => extFull
   );
   end generate;
   ---------------------------------------------------


   ---------------------------------------------------
   -- Combinational logic
   ---------------------------------------------------
   process (curReg, qpixReq, qpixConf, s_extFifoEmpty, extFull, locFull,
            locFifoDout, txReady, extFifoDout, s_locFifoEmpty, clkCnt)
   begin
      nxtReg <= curReg;
      nxtReg.txData.DataValid <= '0';

      nxtReg.manRoute <= qpixConf.ManRoute;
      nxtReg.respDir  <= qpixConf.DirMask;

      if extFull = '1' then 
         nxtReg.extFull <= '1';
      end if;

      if locFull = '1' then
         nxtReg.locFull <= '1';
      end if;
      -----------------------------------------------

      case (curReg.state) is 

         -- waiting for interrogation
         when IDLE_S       =>
            fsmState <= "000";
            nxtReg.stateCnt         <= (others => '0');
            nxtReg.txData.DataValid <= '0';
            nxtReg.locFifoRen       <= '0';
            nxtReg.extFifoRen       <= '0';

            -- -- possible mismatch on softInterr behavior
            -- if qpixReq.InterrogationSoft = '1' then
            --    nxtReg.softInterr <= '1';
            -- end if;

            -- if qpixReq.InterrogationHard = '1' then
            --    nxtReg.softInterr <= '0';
            -- end if;

            if (qpixReq.InterrogationSoft = '1' and s_locFifoEmpty = '0') or
               qpixReq.InterrogationHard = '1' then
                  nxtReg.state   <= REP_LOCAL_S;
                  nxtReg.intTime <= qpixReq.RequestTimestamp;
                  nxtReg.reqID   <= qpixReq.ReqID;
                  nxtReg.intrNum <= curReg.intrNum + 1;
            elsif s_extFifoEmpty = '0' then
               nxtReg.state <= REP_REMOTE_S;
            end if;

         -- report local hits
         when REP_LOCAL_S  =>
            fsmState <= "010";
            nxtReg.locFifoRen <= '0';
            if s_locFifoEmpty = '0' or curReg.stateCnt > to_unsigned(0, G_REG_DATA_BITS) then
               -- buffer for FIFOs with no fall-through word
               if txReady = '1' then
                  nxtReg.stateCnt   <= curReg.stateCnt + 1;
                  if curReg.stateCnt = to_unsigned(0, G_REG_DATA_BITS) then
                     nxtReg.locFifoRen <= '1';
                  elsif curReg.locFifoRen = '0' and curReg.stateCnt = to_unsigned(2, G_REG_DATA_BITS) then
                     nxtReg.txData.DataValid <= '1';
                     nxtReg.txData.XPos      <= qpixConf.XPos;
                     nxtReg.txData.YPos      <= qpixConf.YPos;
                     nxtReg.txData.Timestamp <= locFifoDout(G_TIMESTAMP_BITS - 1 downto 0);
                     nxtReg.txData.ChanMask  <= locFifoDout(G_N_ANALOG_CHAN + G_TIMESTAMP_BITS - 1 downto G_TIMESTAMP_BITS);
                     nxtReg.txData.DirMask   <= curReg.respDir;
                     nxtReg.txData.WordType  <= G_WORD_TYPE_DATA;
                     nxtReg.stateCnt         <= (others => '0');
                  end if;
               end if;

            else
               nxtReg.state      <= REP_FINISH_S;
               nxtReg.stateCnt   <= (others => '0');
            end if;

         -- evt end packet
         when REP_FINISH_S =>
            fsmState <= "011";
            -- all hits are done, send the packet which indicates that
            nxtReg.stateCnt <= curReg.stateCnt + 1;
            if txReady = '1' then
               if curReg.stateCnt = to_unsigned(2, G_REG_DATA_BITS) then
                  nxtReg.txData.DataValid <= '1';
                  nxtReg.txData.ChanMask  <= '0' & curReg.locFull & curReg.extFull & curReg.reqID & 
                                             std_logic_vector(curReg.intrNum(8 downto 0));
                  nxtReg.txData.XPos      <= qpixConf.XPos;
                  nxtReg.txData.YPos      <= qpixConf.YPos;
                  nxtReg.txData.Timestamp <= curReg.intTime; 
                  nxtReg.txData.DirMask   <= curReg.respDir;
                  nxtReg.txData.WordType  <= G_WORD_TYPE_EVTEND;
                  nxtReg.state            <= REP_REMOTE_S;
                  nxtReg.stateCnt         <= (others => '0');

                  nxtReg.extFull <= '0';
                  nxtReg.locFull <= '0';
               end if;
            end if;

         --report external hits being received from neighbour ASICs
         when REP_REMOTE_S =>
            fsmState <= "100";
            nxtReg.extFifoRen       <= '0';
            nxtReg.txData.DataValid <= '0';

            if s_extFifoEmpty = '0' or curReg.stateCnt > to_unsigned(0, G_REG_DATA_BITS) then
               if txReady = '1' then
                  nxtReg.stateCnt   <= curReg.stateCnt + 1;
                  if curReg.stateCnt = to_unsigned(0, G_REG_DATA_BITS) then
                     nxtReg.extFifoRen <= '1';
                  elsif curReg.stateCnt = to_unsigned(2, G_REG_DATA_BITS) then
                     nxtReg.txData           <= fQpixByteToRecord(extFifoDout);
                     -- nxtReg.txData.Data      <= extFifoDout;
                     nxtReg.txData.DataValid <= '1';
                     nxtReg.txData.DirMask   <= curReg.respDir;
					 nxtReg.stateCnt         <= (others => '0');
                  end if;
               end if;

            else
               nxtReg.state <= IDLE_S;
            end if;
            
         when others =>
            fsmState     <= "111";
            nxtReg.state <= IDLE_S;

      end case;
   end process;
   ---------------------------------------------------


   ---------------------------------------------------
   -- Synchronous logic
   ---------------------------------------------------
   process (clk)
   begin
      if rising_edge (clk) then
         if rst = '1' then
            curReg <= REG_INIT_C after GATE_DELAY_G;
         else
            curReg <= nxtReg after GATE_DELAY_G;
         end if;
      end if;
   end process;
   ---------------------------------------------------

   
   txData  <= curReg.txData;
   intrNum <= std_logic_vector(curReg.intrNum);
   busy    <= '0' when curReg.state = IDLE_S else '1';

   extFifoFull <= extFull;
   locFifoFull <= locFull;


end behav;
