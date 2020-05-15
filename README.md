net-telnet-rfc2217 is a gem to allow accessing remote serial ports as an
IO-like object.


Note that the initializer for `RFC2217` class accepts _both_ options like
`Net::Telnet` from the [net-telnet](https://github.com/ruby/net-telnet) gem
_and_ `SerialPort#set_modem_params` from the
[ruby-serialport][http://github.com/hparra/ruby-serialport/] gem. The
latter are passed through telnet to instruct the remote port how to configure
itself. Note that in this early version, only basic port parameters are
supported, not more complicated things like sending and receiving serial
controls like flow control, DTR, RTS, etc.

Example:

```bash
ser2net -C "2217:telnet:0:/dev/ttyUSB0:remctl" -d # start ser2net in RFC2217 mode
```

```ruby
require 'net/telnet/rfc2217'

io = Net::Telnet::RFC2217.new('Host' => '127.0.0.1', 'Port' => 2217, 'baud' => 115200)
data = io.read(20)
io.write("hello")
```
