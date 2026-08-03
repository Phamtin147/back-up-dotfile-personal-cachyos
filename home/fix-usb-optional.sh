#!/bin/bash
VM="${1:-AutoVirt}"
echo "1" | sudo -S EDITOR="sed -i 's|<source>|<source startupPolicy=\"optional\">|g'" virsh edit "$VM" 2>/dev/null
echo "Done! All USB hostdev in $VM now have startupPolicy='optional'"
