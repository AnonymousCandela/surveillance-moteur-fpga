library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.package_constants.all;

entity threshold_classifier is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        rpm_in      : in  unsigned(15 downto 0);
        current_in  : in  unsigned(15 downto 0);

        frame_valid : in  std_logic;

        state_out   : out motor_state_t
    );
end threshold_classifier;
architecture Behavioral of threshold_classifier is

    signal current_state   : motor_state_t := NORMAL;
    signal candidate_state : motor_state_t := NORMAL;

    signal confirm_counter : integer range 0 to CONFIRM_COUNT := 0;

begin

    state_out <= current_state;

    process(clk)
        variable detected_state : motor_state_t;
    begin
        if rising_edge(clk) then

            if reset = '1' then

                current_state   <= NORMAL;
                candidate_state <= NORMAL;
                confirm_counter <= 0;

            elsif frame_valid = '1' then

                --------------------------------------------------------
                -- Détermination de l’état indiqué par la mesure reçue
                --------------------------------------------------------

                if (rpm_in <= RPM_FAULT_LIMIT) or
                   (current_in >= CURRENT_FAULT_LIMIT) then

                    detected_state := FAULT;

                elsif (rpm_in >= RPM_NORMAL_MIN) and
                      (rpm_in <= RPM_NORMAL_MAX) and
                      (current_in >= CURRENT_NORMAL_MIN) and
                      (current_in <= CURRENT_NORMAL_MAX) then

                    detected_state := NORMAL;

                else

                    detected_state := DEGRADE;

                end if;

                --------------------------------------------------------
                -- Confirmation de l’état sur plusieurs mesures
                --------------------------------------------------------

                if detected_state = FAULT then

                    -- Securite : le defaut est applique immediatement,
                    -- sans attendre les mesures de confirmation.
                    current_state   <= FAULT;
                    candidate_state <= FAULT;
                    confirm_counter <= 0;

                elsif detected_state = current_state then

                    -- Le moteur reste dans son état officiel actuel.
                    candidate_state <= detected_state;
                    confirm_counter <= 0;

                elsif detected_state = candidate_state then

                    -- Une nouvelle mesure confirme le même candidat.
                    if confirm_counter = CONFIRM_COUNT - 1 then

                        current_state   <= detected_state;
                        candidate_state <= detected_state;
                        confirm_counter <= 0;

                    else

                        confirm_counter <= confirm_counter + 1;

                    end if;

                else

                    -- Un nouvel état candidat vient d’être détecté.
                    candidate_state <= detected_state;
                    confirm_counter <= 1;

                end if;

            end if;

        end if;
    end process;

end Behavioral;