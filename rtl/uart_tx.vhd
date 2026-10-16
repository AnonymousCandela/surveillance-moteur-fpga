library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.package_constants.all;

entity uart_tx is
    Port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        state_in : in  motor_state_t;
        send     : in  std_logic;

        tx       : out std_logic;
        busy     : out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is

    constant BAUD_TICK : integer := CLOCK_FREQ / BAUD_RATE;

    type tx_state_t is (
        IDLE,
        LOAD_BYTE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        NEXT_BYTE
    );

    signal tx_state      : tx_state_t := IDLE;

    signal baud_counter  : integer range 0 to BAUD_TICK - 1 := 0;
    signal bit_index     : integer range 0 to 7 := 0;
    signal byte_index    : integer range 0 to 2 := 0;

    signal shift_reg     : std_logic_vector(7 downto 0) := (others => '0');
    signal state_code    : std_logic_vector(7 downto 0) := STATE_NORMAL_CODE;

    signal tx_reg        : std_logic := '1';
    signal busy_reg      : std_logic := '0';

begin

    tx   <= tx_reg;
    busy <= busy_reg;

    --------------------------------------------------------------------
    -- Conversion de l’état interne en code transmis à l’Arduino
    --------------------------------------------------------------------
    process(state_in)
    begin
        case state_in is

            when NORMAL =>
                state_code <= STATE_NORMAL_CODE;

            when DEGRADE =>
                state_code <= STATE_DEGRADE_CODE;

            when FAULT =>
                state_code <= STATE_FAULT_CODE;

        end case;
    end process;

    --------------------------------------------------------------------
    -- Machine d’émission UART
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                tx_state     <= IDLE;
                baud_counter <= 0;
                bit_index    <= 0;
                byte_index   <= 0;
                shift_reg    <= (others => '0');
                tx_reg       <= '1';
                busy_reg     <= '0';

            else

                case tx_state is

                    ----------------------------------------------------
                    -- Attente d’une demande de transmission
                    ----------------------------------------------------
                    when IDLE =>

                        tx_reg       <= '1';
                        busy_reg     <= '0';
                        baud_counter <= 0;
                        bit_index    <= 0;
                        byte_index   <= 0;

                        if send = '1' then
                            busy_reg <= '1';
                            tx_state <= LOAD_BYTE;
                        end if;

                    ----------------------------------------------------
                    -- Chargement de l’octet à transmettre
                    ----------------------------------------------------
                    when LOAD_BYTE =>

                        case byte_index is

                            when 0 =>
                                shift_reg <= UART_START;

                            when 1 =>
                                shift_reg <= state_code;

                            when 2 =>
                                shift_reg <= UART_STOP;

                            when others =>
                                shift_reg <= UART_STOP;

                        end case;

                        baud_counter <= 0;
                        tx_state     <= START_BIT;

                    ----------------------------------------------------
                    -- Bit de départ UART
                    ----------------------------------------------------
                    when START_BIT =>

                        tx_reg <= '0';

                        if baud_counter = BAUD_TICK - 1 then
                            baud_counter <= 0;
                            bit_index    <= 0;
                            tx_state     <= DATA_BITS;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    ----------------------------------------------------
                    -- Transmission des 8 bits, bit faible en premier
                    ----------------------------------------------------
                    when DATA_BITS =>

                        tx_reg <= shift_reg(bit_index);

                        if baud_counter = BAUD_TICK - 1 then

                            baud_counter <= 0;

                            if bit_index = 7 then
                                bit_index <= 0;
                                tx_state  <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;

                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    ----------------------------------------------------
                    -- Bit d’arrêt UART
                    ----------------------------------------------------
                    when STOP_BIT =>

                        tx_reg <= '1';

                        if baud_counter = BAUD_TICK - 1 then
                            baud_counter <= 0;
                            tx_state     <= NEXT_BYTE;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    ----------------------------------------------------
                    -- Passage à l’octet suivant
                    ----------------------------------------------------
                    when NEXT_BYTE =>

                        if byte_index = 2 then

                            byte_index <= 0;
                            busy_reg   <= '0';
                            tx_state   <= IDLE;

                        else

                            byte_index <= byte_index + 1;
                            tx_state   <= LOAD_BYTE;

                        end if;

                end case;

            end if;

        end if;
    end process;

end Behavioral;