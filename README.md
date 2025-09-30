This TCP ping shell script utilizes pure Bash and nc to achieve TCP ping. It has colorful statistics output (including uptime/downtime) on exit. 

Requires: nc (netcat-openbsd), awk, date (GNU coreutils). 

One command to start：

```bash
curl -L https://raw.githubusercontent.com/RomanovCaesar/TCPing/refs/heads/main/tcping.sh && chmod +x tcping.sh
```

Usage:

```bash
./tcping.sh [-4|-6] host port [count]
```

1. Testing IPv4

```bash
./tcping.sh -4 example.com 80 
```

2. Testing IPv6 (Please note that using square brackets around IPv6 addresses) 

```bash
./tcping.sh -6 [2001:db8::1] 80 
```

3. Continuous loop (count=0 represents infinite)

```bash
./tcping.sh -4 example.com 80 0 
```
