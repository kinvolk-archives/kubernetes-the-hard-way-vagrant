#!/bin/bash

set -euo pipefail

case "$(hostname)" in
worker-0)
  route add -net 10.21.0.0/16 gw 192.168.199.21
  route add -net 10.22.0.0/16 gw 192.168.199.22
  ;;
worker-1)
  route add -net 10.20.0.0/16 gw 192.168.199.20
  route add -net 10.22.0.0/16 gw 192.168.199.22
  ;;
worker-2)
  route add -net 10.20.0.0/16 gw 192.168.199.20
  route add -net 10.21.0.0/16 gw 192.168.199.21
  ;;
*)
  route add -net 10.20.0.0/16 gw 192.168.199.20
  route add -net 10.21.0.0/16 gw 192.168.199.21
  route add -net 10.22.0.0/16 gw 192.168.199.22
  ;;
esac
