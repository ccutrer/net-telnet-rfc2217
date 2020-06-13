require 'net/telnet'
require 'byebug'

# have to patch Telnet to allow us to read control sequences
require 'net/telnet/rfc2217/telnet'
Net::Telnet.prepend(Net::Telnet::RFC2217::TelnetExtensions)

module Net
  class Telnet
    class RFC2217
      class WaitReadable < RuntimeError
        include ::IO::WaitReadable
      end

      attr_reader :telnet

      COM_PORT_OPTION = 44.chr

      SET_BAUDRATE = 1.chr
      SET_DATASIZE = 2.chr
      SET_PARITY = 3.chr
      SET_STOPSIZE = 4.chr
      SET_CONTROL = 5.chr
      NOTIFY_LINESTATE = 6.chr
      NOTIFY_MODEMSTATE = 7.chr
      FLOWCONTROL_SUSPEND = 8.chr
      SET_LINESTATE_MASK = 10.chr
      SET_MODEMSTATE_MASK = 11.chr
      PURGE_DATA = 12.chr

      SET_BAUDRATE_RESPONSE = 101.chr
      SET_DATASIZE_RESPONSE = 102.chr
      SET_PARITY_RESPONSE = 103.chr
      SET_STOPSIZE_RESPONSE = 104.chr
      SET_CONTROL_RESPONSE = 105.chr
      NOTIFY_LINESTATE_RESPONSE = 106.chr
      NOTIFY_MODEMSTATE_RESPONSE = 107.chr
      FLOWCONTROL_SUSPEND_RESPONSE = 108.chr
      SET_LINESTATE_MASK_RESPONSE = 110.chr
      SET_MODEMSTATE_MASK_RESPONSE = 111.chr
      PURGE_DATA_RESPONSE = 112.chr

      NONE = 1
      ODD = 2
      EVEN = 3
      MARK = 4
      SPACE = 5

      SERIAL_PORT_PARAMS = %w{baud data_bits stop_bits parity}.freeze

      class << self
        def open(options)
          sp = new(options)
          if block_given?
            begin
              yield sp
            ensure
              sp.close
            end
            nil
          else
            nil
          end
        end
      end

      def initialize(options = {}, &block)
        set_modem_params(options.slice(*SERIAL_PORT_PARAMS))

        options['Binmode'] = true
        options['Telnetmode'] = false
        @telnet = Telnet.new(options, &block)
        telnet.write(IAC + WILL + COM_PORT_OPTION)
        sock.flush
        @buffer = ''
        start = Time.now.to_f
        loop do
          raise "could not negotiate serial port in time" if Time.now.to_f - start > 5
          break if @negotiated
          readpartial(0)
        end
      end

      def get_modem_params
        @modem_params
      end

      def set_modem_params(modem_params)
        @modem_params = modem_params.dup
        @modem_params['baud'] = 115200 unless @modem_params.key?('baud')
        @modem_params['data_bits'] = 8 unless @modem_params.key?('data_bits')
        @modem_params['stop_bits'] = 1 unless @modem_params.key?('stop_bits')
        unless @modem_params.key?('parity')
          @modem_params['parity'] = (data_bits == 8 ? NONE : EVEN)
        end
        write_modem_params if telnet
      end

      def baud
        get_modem_params['baud']
      end

      def data_bits
        get_modem_params['data_bits']
      end

      def stop_bits
        get_modem_params['stop_bits']
      end

      def parity
        get_modem_params['parity']
      end

      def sock
        @telnet.sock
      end

      def read(length, outbuf = '')
        readpartial(length, outbuf)
        while outbuf.length < length
          outbuf.concat(readpartial(length - outbuf.length))
        end
        outbuf
      end

      def readbyte
        read(1)&.[](0)
      end

      def readpartial(length, outbuf = '')
        loop do
          # 0 is special and means "just see if there's data to read"
          break if length != 0 && @buffer.length != 0
          raise "could not negotiate serial port in first 1MB of data" if @buffer.length >= 1024 * 1024

          data = sock.sysread([length - @buffer.length, 64 * 1024].max)

          # avoid getting caught in the middle of a control sequence
          while (data[-1] == IAC && sock.wait_readable(0))
            data.concat(sock.sysread(16))
          end

          data = @telnet.preprocess(data) do |control|
            if DO[0] == control[0] && COM_PORT_OPTION == control[1]
              # start negotiation
              write_modem_params
              @negotiated = true
              true
            elsif DONT[0] == control[0] && COM_PORT_OPTION == control[1]
              raise "Serial port control not supported"
            elsif (WILL[0] == control[0] || DONT[0] == control[0]) && OPT_ECHO == control[1]
              # just ignore echo requests
              true
            else
              false
            end
          end
          @buffer.concat(data)

          break if length == 0
        end

        length = [length, @buffer.length].min
        outbuf.replace(@buffer[0...length])
        @buffer = @buffer[length..-1]
        outbuf
      end

      def read_nonblock(length, outbuf = '', options = {})
        if outbuf == ({ exception: false })
          options = outbuf
          outbuf = ''
        end
        loop do
          result = wait_readable(0)
          if result == nil
            raise WaitReadable unless options[:exception] == false
            return :wait_readable
          end
          # we have to try to consume control characters first
          readpartial(0)
          # and then only do a real read if we have something
          return readpartial(length, outbuf) unless @buffer.empty?
          # otherwise loop and see if there's more there
        end
      end

      def wait_readable(timeout = nil)
        return true unless @buffer.empty?
        result = sock.wait_readable(timeout)
        result = self if result == sock
        result
      end

      def ungetbyte(b)
        @buffer.insert(0, b.chr)
      end

      def ungetc(c)
        @buffer.insert(0, c)
      end

      def write(string)
        string = string.gsub(/#{IAC}/no, IAC + IAC)
        telnet.write(string)
      end

      def flush
        sock.flush
      end

      def close
        telnet.close
      end

      private

      def write_modem_params
        telnet.write(
          IAC + SB + COM_PORT_OPTION + SET_BAUDRATE + [baud].pack("N") + IAC + SE +
          IAC + SB + COM_PORT_OPTION + SET_DATASIZE + data_bits.chr + IAC + SE +
          IAC + SB + COM_PORT_OPTION + SET_STOPSIZE + stop_bits.chr + IAC + SE +
          IAC + SB + COM_PORT_OPTION + SET_PARITY + parity.chr + IAC + SE)
        sock.flush
      end
    end
  end
end
