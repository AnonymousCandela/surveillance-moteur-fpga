library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.package_constants.all;

entity rx_frame_handler is

    Port(

        clk         : in  std_logic;
        reset       : in  std_logic;

        data_in     : in  std_logic_vector(7 downto 0);
        data_ready  : in  std_logic;

        rpm_out     : out unsigned(15 downto 0);
        current_out : out unsigned(15 downto 0);

        frame_valid : out std_logic

    );

end rx_frame_handler;

architecture Behavioral of rx_frame_handler is

    --------------------------------------------------------------------
    -- Etats de la machine
    --------------------------------------------------------------------

    type state_type is (

        ST_WAIT_START,
        ST_RPM_H,
        ST_RPM_L,
        ST_CUR_H,
        ST_CUR_L,
        ST_CHECKSUM,
        ST_WAIT_STOP

    );

    signal state : state_type := ST_WAIT_START;

    --------------------------------------------------------------------
    -- Registres
    --------------------------------------------------------------------

    signal rpm_high      : std_logic_vector(7 downto 0) := (others => '0');
    signal rpm_low       : std_logic_vector(7 downto 0) := (others => '0');

    signal current_high  : std_logic_vector(7 downto 0) := (others => '0');
    signal current_low   : std_logic_vector(7 downto 0) := (others => '0');

    signal checksum_rx   : std_logic_vector(7 downto 0) := (others => '0');

begin

process(clk, reset)

    variable checksum_v : std_logic_vector(7 downto 0);

begin

    if reset='1' then

        state <= ST_WAIT_START;

        rpm_out <= (others=>'0');
        current_out <= (others=>'0');

        frame_valid <= '0';

    elsif rising_edge(clk) then

        frame_valid <= '0';

        if data_ready='1' then

            case state is

            ----------------------------------------------------------

            when ST_WAIT_START =>

                if data_in = UART_START then

                    state <= ST_RPM_H;

                end if;

            ----------------------------------------------------------

            when ST_RPM_H =>

                rpm_high <= data_in;

                state <= ST_RPM_L;

            ----------------------------------------------------------

            when ST_RPM_L =>

                rpm_low <= data_in;

                state <= ST_CUR_H;

            ----------------------------------------------------------

            when ST_CUR_H =>

                current_high <= data_in;

                state <= ST_CUR_L;

            ----------------------------------------------------------

            when ST_CUR_L =>

                current_low <= data_in;

                state <= ST_CHECKSUM;

            ----------------------------------------------------------

            when ST_CHECKSUM =>

                checksum_rx <= data_in;

                state <= ST_WAIT_STOP;

            ----------------------------------------------------------

            when ST_WAIT_STOP =>

                if data_in = UART_STOP then

                    checksum_v :=
                        rpm_high xor
                        rpm_low xor
                        current_high xor
                        current_low;

                    if checksum_rx = checksum_v then

                        rpm_out <= unsigned(rpm_high & rpm_low);

                        current_out <= unsigned(current_high & current_low);

                        frame_valid <= '1';

                    end if;

                end if;

                state <= ST_WAIT_START;

            ----------------------------------------------------------

            end case;

        end if;

    end if;

end process;

end Behavioral;