----------------------------------------------------------------------------------
-- QPix data parser
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.QpixPkg.all;


entity QpixParser is
   generic (
      NUM_BITS_G      : natural := 64;
      GATE_DELAY_G    : time    := 1 ns;
      X_POS_G         : natural := 0;
      Y_POS_G         : natural := 0
   );
   port (
      clk                 : in std_logic;
      rst                 : in std_logic;
      
      -- input to ASIC 
      inBytesArr          : in  QpixByteArrType;
      inFifoEmptyArr      : in  std_logic_vector(3 downto 0); 
      inFifoREnArr        : out std_logic_vector(3 downto 0);
      inData              : out QpixDataFormatType;
      
      -- output from ASIC
      outData             : in  QpixDataFormatType;
      outBytesArr         : out QpixByteArrType;
      outBytesValidArr    : out std_logic_vector(3 downto 0);
      txReady             : in  std_logic;

-- -- Fixme / TODO?? - These ports do nothing in this module
--      qpixConf            : out QpixConfigType;
--      qpixReq             : out QpixRequestType;

      regData             : out QpixRegDataType;
      regResp             : in QpixRegDataType
      
   );
end entity QpixParser;


architecture behav of QpixParser is

   signal regDataR         : QpixRegDataType    := QpixRegDataZero_C;
   signal inDataR          : QpixDataFormatType := QpixDataZero_C;

   signal thisReqID        : std_logic_vector(regDataR.ReqID'range) := (others => '0');
   signal thisReqDaq       : std_logic := '0';

   signal inBytesMux       : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0');
   signal inBytesMuxValid  : std_logic                    := '0';
   signal inBytesValid     : std_logic_vector(3 downto 0) := (others => '0');

   signal regDir           : std_logic_vector(3 downto 0) := (others => '0');
   signal regDirResp       : std_logic_vector(3 downto 0) := (others => '0');
   signal fifoRen          : std_logic_vector(3 downto 0) := (others => '0');

   signal txReadyR         : std_logic  := '1';
   signal fifoRenOrR       : std_logic  := '0';
   signal fifoRenOrRR       : std_logic := '0';

   type MuxStatesType is (IDLE_S, READ_S, WAIT_S);
   signal muxState : MuxStatesType := IDLE_S;

   function fGetFirstZeroPos(x : std_logic_vector) return natural is
      variable pos : natural := 0;
   begin
      for i in x'range loop
         if x(i) = '0' then
            pos := i;
            return pos;
         end if;
      end loop;
      return pos;
   end function;
   

begin


   ------------------------------------------------------------
   -- mux for input channels
   ------------------------------------------------------------
   process (clk)
      variable imux : natural := 0;
   begin
      if rising_edge (clk) then

         inBytesMuxValid <= '0';
         fifoRen         <= (others => '0');
         txReadyR        <= txReady;
         fifoRenOrR      <= or fifoRen;
         fifoRenOrRR     <= fifoRenOrR;
         for i in 0 to 3 loop
            --fifoRen(i)   <= '0';
            if inFifoEmptyArr(i) = '0' and fifoRen = b"0000" and txReady = '1' then
               inBytesMux          <= inBytesArr(i);
               inBytesMuxValid     <= '1';
               inBytesValid    <= (others => '0');
               inBytesValid(i)     <= '1';
               fifoRen <= (others => '0');
               fifoRen(i)   <= '1';
            end if;
         end loop;
         
      end if;
   end process;
   ------------------------------------------------------------
   inFifoREnArr <= fifoRen;


   ------------------------------------------------------------
   -- RX parsing
   ------------------------------------------------------------
   --process (clk)
   --begin
      --if rising_edge (clk) then
         --case rxState is 
            --when IDLE_S => 
            --when RD_S   =>
            --when 
         --end case;
      --end if;
   --end process;

   regDirResp <= fQpixGetDirectionMask(X_POS_G, Y_POS_G); -- FIXME shoud be from qpixConf

   process (clk)
   begin
      if rising_edge (clk) then
         if rst = '1' then 
            inDataR  <= QpixDataZero_C;
            regDataR <= QpixRegDataZero_C;
         else
            inDataR.DataValid <= '0';
            regDataR.Valid <= '0';
            regDataR.OpWrite <= '0';
            regDataR.OpRead  <= '0';
            --end if;
            if inBytesMuxValid = '1'  then
               if fQpixGetWordType(inBytesMux) = REGREQ_W then
                  regDataR.Valid    <= '1';
                  --regDataR.Addr     <= inBytesMux(31 downto 31 - G_REG_ADDR_BITS + 1);
                  regDataR.Addr     <= inBytesMux(31 downto 16);
                  regDataR.Data     <= inBytesMux(15 downto  0);
                  regDataR.XDest    <= inBytesMux(39 downto 36);
                  regDataR.YDest    <= inBytesMux(35 downto 32);
                  regDataR.OpWrite  <= inBytesMux(55);
                  regDataR.OpRead   <= inBytesMux(54);
                  regDataR.Dest     <= inBytesMux(53);
                  regDataR.ReqID    <= inBytesMux(52 downto 49);
                  regDataR.SrcDaq   <= inBytesMux(48);
                  --regDataR.ReqID    <= thisReqID;
                  --thisReqDaq        <= inBytesMux(48); -- came from DAQ node
                  regDir            <= DirDown or DirRight;
                  inDataR.DataValid <= '0';

               else
                  regDataR.Valid    <= '0';
                  inDataR           <= fQpixByteToRecord(inBytesMux);
                  inDataR.Data      <= inBytesMux;
                  inDataR.DataValid <= '1';
               end if;
            end if;
         end if;
      end if;
   end process;

   regData <= regDataR;
   inData  <= inDataR;
   ------------------------------------------------------------

   ------------------------------------------------------------
   -- TX
   ------------------------------------------------------------
   process (clk)
   begin
      if rising_edge (clk) then
         if regDataR.Valid = '1'  then 
            thisReqID           <= regDataR.ReqID;
         end if;
      end if;
   end process;
         
   TX_GEN : for i in 0 to 3 generate
      process (clk)
      begin
         if rising_edge (clk) then
            outBytesValidArr(i)  <= '0';
            if outData.DataValid = '1' then
               if outData.DirMask(i) = '1' then
                  -- temporary send either d.Data of convert record FIXME
                  if outData.WordType = G_WORD_TYPE_REGRSP then
                     outBytesArr(i) <= outData.Data;
                  else
                     outBytesArr(i) <= fQpixRecordToByte(outData);
                  end if;
                  outBytesValidArr(i)  <= '1'; 
               end if;
            elsif regDataR.Valid = '1'  then 
               outBytesArr(i)      <= fQpixRegToByte(regDataR);
               --thisReqID           <= regDataR.ReqID;
               if regDataR.ReqID /= thisReqID then
                  outBytesValidArr(i) <= not inBytesValid(i);
               else 
                  outBytesValidArr(i) <= '0';
               end if;

               --if thisReqDaq = '1' then
                  --outBytesValidArr(i) <= not inBytesValid(i);
                  --thisReqID <= thisReqID + 1;
               --else
                  --if regDataR.ReqID /= thisReqID then
                     --outBytesValidArr(i) <= not inBytesValid(i);
                  --else 
                     --outBytesValidArr(i) <= '0';
                  --end if;
               --end if;
               --outBytesValidArr(i) <= regDir(i);
            elsif regResp.Valid = '1' then
               outBytesArr(i)      <= fQpixRegToByte(regResp);
               outBytesValidArr(i) <= regDirResp(i);
            end if;
         end if;
      end process;
   end generate;
   ------------------------------------------------------------



end behav;

