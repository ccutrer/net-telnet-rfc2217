module Net
  class Telnet
    module RFC2217::TelnetExtensions
      def preprocess(string)
        # combine CR+NULL into CR
        string = string.gsub(/#{CR}#{NULL}/no, CR) if @options["Telnetmode"]

        # combine EOL into "\n"
        string = string.gsub(/#{EOL}/no, "\n") unless @options["Binmode"]

        # remove NULL
        string = string.gsub(/#{NULL}/no, '') unless @options["Binmode"]

        string.gsub(/#{IAC}(
                    [#{IAC}#{AO}#{AYT}#{DM}#{IP}#{NOP}]|
                    [#{DO}#{DONT}#{WILL}#{WONT}]
                      [#{OPT_BINARY}-#{OPT_NEW_ENVIRON}#{44.chr}#{OPT_EXOPL}]|
                    #{SB}[^#{IAC}]*#{IAC}#{SE}
                  )/xno) do
          if block_given? && IAC != $1
            # already handled; don't handle it ourselves
            next '' if yield $1
          end

          if    IAC == $1  # handle escaped IAC characters
            IAC
          elsif AYT == $1  # respond to "IAC AYT" (are you there)
            self.write("nobody here but us pigeons" + EOL)
            ''
          elsif DO[0] == $1[0]  # respond to "IAC DO x"
            if OPT_BINARY[0] == $1[1]
              unless @telnet_option["BINARY"] == true
                @telnet_option["BINARY"] = true
                self.write(IAC + WILL + OPT_BINARY)
              end
            else
              self.write(IAC + WONT + $1[1..1])
            end
            ''
          elsif DONT[0] == $1[0]  # respond to "IAC DON'T x" with "IAC WON'T x"
            self.write(IAC + WONT + $1[1..1])
            ''
          elsif WILL[0] == $1[0]  # respond to "IAC WILL x"
            if    OPT_BINARY[0] == $1[1]
              self.write(IAC + DO + OPT_BINARY)
            elsif OPT_ECHO[0] == $1[1]
              self.write(IAC + DO + OPT_ECHO)
            elsif OPT_SGA[0]  == $1[1]
              unless @telnet_option["SGA"]
                @telnet_option["SGA"] = true
                self.write(IAC + DO + OPT_SGA)
              end
            else
              self.write(IAC + DONT + $1[1..1])
            end
            ''
          elsif WONT[0] == $1[0]  # respond to "IAC WON'T x"
            if    OPT_ECHO[0] == $1[1]
              self.write(IAC + DONT + OPT_ECHO)
            elsif OPT_SGA[0]  == $1[1]
              unless @telnet_option["SGA"] == false
                @telnet_option["SGA"] = false
                self.write(IAC + DONT + OPT_SGA)
              end
            else
              self.write(IAC + DONT + $1[1..1])
            end
            ''
          elsif SB[0] == $1[0] # yield sub option
            ''
          else
            ''
          end
        end
      end # preprocess
    end
  end
end
